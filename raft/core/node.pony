use "collections"
use "logger"
use "raft"
use "random"
use "time"
use "debug"

trait LogEntry is Equatable[LogEntry]
  fun box index(): USize
  fun box term(): U64
  fun box eq(that: box->LogEntry): Bool=>
    (index() == that.index()) and (term() == that.term())
  fun box nw(that: box->LogEntry): Bool=>
    not eq(that)

class BaseLogEntry is LogEntry
  var _term: U64
  var _log_index: USize
  
  new create(log_term: U64 = 0, log_index: USize = 0) =>
    _term = log_term
    _log_index = log_index
  
  fun index(): USize => _log_index

  fun term(): U64 => _term
  
class NullLogEntry is LogEntry
  let _base: BaseLogEntry delegate LogEntry = BaseLogEntry()
  
class FirstLogEntry is LogEntry
  let _base: BaseLogEntry delegate LogEntry = BaseLogEntry(0, 1)
  
type NodeMap[A] is HashMap[Node tag, A, HashIs[Node tag]]

trait Node
  // Add log entries to the node's log
  be append_entries(
      term: U64,
      leader: Node tag,
      prev_log_index: USize,
      prev_log_term: U64,
      entries: List[LogEntry val] val,
      leader_commit: USize) => None

  //  Decide to vote for a candidate
  be request_vote(
      term: U64,
      candidate: Node tag,
      last_log_term: U64,
      last_log_index: USize) => None

  be ack_entries(n:Node tag, last_index: USize, success: Bool) => None

  be vote_result(n: Node tag, term: U64, result: Bool) => None

  be start(nodes: Array[Node tag] iso) => None

actor NullNode is Node

primitive Follower
primitive Candidate
primitive Leader

type NodeStatus is (Follower | Candidate | Leader)

class _TimeoutNotify is TimerNotify
  let n: MainNode tag
  new iso create(n': MainNode tag) => n=n'
  fun ref apply(t: Timer, c: U64): Bool =>
    n.do_timeout()
    false

class _HeartbeatNotify is TimerNotify
  let n: MainNode tag
  var count: U64 = 0
  new iso create(n': MainNode tag) => n=n'
  fun ref apply(t: Timer, c: U64): Bool =>
    n.do_heartbeat()
    count = count + 1
    if (count % 100) == 0 then
      false
    else 
      true
    end

actor MainNode is Node
  // persistent state
  var current_term: U64 = 0
  var voted_for: Node tag = NullNode
  // a linked list of log entries. the head is the most recent entry
  embed log: List[LogEntry val] = List[LogEntry val]

  // volatile state
  var commit_index: USize = 0
  var last_applied: USize = 0
  var beatTS: U64  = 0  // timestamp of last heartbeat from the leader
  var current_leader: Node tag = NullNode

  // leader state
  let next_index: NodeMap[USize] = NodeMap[USize]
  let match_index: NodeMap[USize] = NodeMap[USize]
  var heartbeat_timer: Timer tag

  // candidate state
  var current_votes: USize = 0

  // misc
  let id: String
  var status: NodeStatus = Follower
  var timeout: U64
  var min_timeout: U64 = 150_000_000
  var max_timeout: U64 = 300_000_000
  let heartbeat: U64 = 15_000_000
  let logger: Logger[String]
  let mt: MT
  let timers: Timers = Timers
  var peers: Array[Node tag] val = recover val Array[Node tag] end

  new create(name: String, l: Logger[String], c: Cluster tag) =>
    logger = l 
    id = name
    mt = MT(Time.nanos())
    timeout = max_timeout
    c.ready(this)
    log.unshift(NullLogEntry)
    log.unshift(FirstLogEntry)
    voted_for = this  // just to initialise
    heartbeat_timer = Timer(_HeartbeatNotify(this),0)
  
  fun logg(level: (LogLevel | String), msg: String): Bool =>
    (let s, let n) = Time.now()
    let d = Date(s, n)
    let d' = d.format("%T")
    let millis = d.nsec / 1000000
    let lvl = match level
    | Fine => "FINE   "
    | Info => "INFO   "
    | Warn => "WARNING"
    | Error => "ERROR  "
    | let st: String => st
    else
      " ***** "
    end
    logger.log("[" + d'  + "." + millis.string() + "] " + lvl + " " + id + ": " + msg) 
    true

  be do_timeout() =>
    if status is Leader then
      return
    end
    var delay = Time.nanos() - beatTS
    if delay >= timeout then
      logger(Info) and logg(Info, "timeout")
      try
        promote_candidate()
      else
        logger(Error) and logg(Error, "No last log")
        promote_follower()
      end
      // reset election timer in any case
      delay = 0
    end
    let t = Timer(_TimeoutNotify(this),timeout-delay)
    timers(consume t)

  fun ref promote_candidate() ? =>
    logger(Info) and logg(Info, "promote to candidate")
    status = Candidate
    current_term = current_term + 1
    voted_for = this
    current_votes = 1
    for peer in peers.values() do
      peer.request_vote(current_term, this, last_entry().term(), last_entry().index()) 
    end

  fun ref last_entry(): LogEntry val ? =>
     log(0)

  be ack_entries(n:Node tag, last_index: USize, success: Bool) =>
    logger(Fine) and logg(Fine, "Acknowledged. success: " + success.string() + " idx: " + last_index.string())
    if success then
      match_index.update(n, last_index)
      var count = USize(0)
      if commit_index >= last_index then
        return
      end
      for i in match_index.values() do
        if i >= last_index then
          count = count + 1
        end
      end
      if count >= (peers.size() / 2) then
        commit_index = last_index
      end
    else
      replicate_log(n)
    end

  be append_entries(
      term: U64,
      leader: Node tag,
      prev_log_index: USize,
      prev_log_term: U64,
      entries: List[LogEntry val] val,
      leader_commit: USize) =>
    """
    Add log entries to the node's log
    """
    logger(Fine) and logg("DEBUG  ", "recieved log")
    // acknowledge the heartbeat
    beatTS = Time.nanos()
    // demote if we're leader
    if status is Leader then
      promote_follower()
      current_leader = leader
    end
    // update term
    if term > current_term then
      voted_for = NullNode
      current_term = term
      current_leader = leader
    end

    // apply the rules described in the paper
    // Reply false if term < currentTerm (§5.1)
    if term < current_term then
      leader.ack_entries(this, prev_log_index, false) 
      return
    end

    // Reply false if log doesn’t contain an entry at prevLogIndex whose
    // term matches prevLogTerm (§5.3)
    let prev_entry = try
      log(log.size() - prev_log_index)
    else
      leader.ack_entries(this, prev_log_index, false) 
      return
    end
    if prev_entry.term() != prev_log_term then
      leader.ack_entries(this, prev_log_index, false) 
      return
    end

    var last_index = prev_log_index
    for entry in entries.values() do
      last_index = entry.index()
      // If an existing entry conflicts with a new one (same index
      // but different terms), delete the existing entry and all that
      // follow it (§5.3)

      // Append any new entries not already in the log
    end

    // If leaderCommit > commitIndex, set commitIndex =
    // min(leaderCommit, index of last new entry)
    if leader_commit > commit_index then
      commit_index = leader_commit.min(last_index)
    end
    leader.ack_entries(this, last_index, true) 

  fun ref replicate_log(peer: Node tag) =>
    let idx = try next_index(peer) else USize(0) end

    var prev_log_term = current_term
    let entries': List[LogEntry val] trn = recover trn List[LogEntry val] end
    for e in log.values() do
      if e is NullLogEntry then
        continue
      else
        if e.index() > idx then
          entries'.push(e)
        else
          prev_log_term = e.term()
          break
        end
      end
    end
    let entries: List[LogEntry val] val = consume entries'
    // send entries
    logger(Fine) and logg("DEBUG  ", "send log")
    peer.append_entries(current_term, this, idx, prev_log_term,
      consume entries, commit_index)
  
  be do_heartbeat() =>
    logger(Fine) and logg("DEBUG  ", "do heartbeat")
    for peer in peers.values() do
      replicate_log(peer)
    end


      /*// calculate missing entries for the peer*/
      /*let next_index = try _get_entry(next_index(peer))*/
      /*else*/
        /*try*/
          /*peer.append_entries(current_term, this, next_index(peer), current_term,*/
            /*recover val List[LogEntry val] end, commit_index)*/
        /*end*/
        /*return*/
      /*end*/
      /*// Null log entry is either the first entry or tells that the peer*/
      /*// did not send its state for the term*/
        
      /*let entries': List[LogEntry val] trn = recover trn List[LogEntry val] end*/
      /*for e in log.values() do*/
        /*if e == last_peer_entry then*/
          /*break*/
        /*else*/
          /*entries'.push(e)*/
        /*end*/
      /*end*/
      /*let entries: List[LogEntry val] val = consume entries'*/
      /*let prev_log_index = last_peer_entry.index()*/
      /*let prev_log_term = last_peer_entry.term()*/
      /*// send entries*/
      /*logger(Fine) and logg("DEBUG  ", "send log")*/
      /*peer.append_entries(current_term, this, prev_log_index, prev_log_term,*/
        /*consume entries, commit_index)*/
    /*end*/

  be request_vote(
      term: U64,
      candidate: Node tag,
      last_log_term: U64,
      last_log_index: USize) =>
   """
   Decide to vote for a candidate
   """
   logger(Info) and logg(Info, "Vote requested")
   try
     if term < current_term then
       logger(Info) and logg(Info, "Vote refused, lesser term")
       candidate.vote_result(this, term, false)
       return
     end
     match voted_for
     | let n: NullNode tag => None 
     /*| candidate => None*/
     else
       logger(Info) and logg(Info, "Vote refused, already granted my vote")
       candidate.vote_result(this, term, false)
       return
     end
     if (last_log_term >= last_entry().term())
        and (last_log_index >= last_entry().index())
     then
       logger(Info) and logg(Info, "Vote granted")
       voted_for = candidate
       candidate.vote_result(this, term, true)
     else
       logger(Info) and logg(Info, "Vote refused, outdated last entry")
       candidate.vote_result(this, term, false)
     end
   else
     logger(Info) and logg(Info, "Vote refused, error occured")
     candidate.vote_result(this, term, false)
   end

  fun ref _get_entry(idx: USize): LogEntry val =>
    try log(log.size() - idx) else NullLogEntry end

  be vote_result(n: Node tag, term: U64, result: Bool) =>
    logger(Info) and logg(Info, "Vote result")
    if status isnt Candidate then
      logger(Info) and logg(Info, "Vote refused: not candidate")
      return
    end
    if term != current_term then 
      logger(Info) and logg(Info, "Vote refused: bad term")
      return
    end
    if result then
      logger(Info) and logg(Info, "Vote granted")
      current_votes = current_votes + 1
      if current_votes > (peers.size() / 2) then
      try promote_leader() else promote_follower() end
      end
    end

  fun ref promote_leader() ? =>
    logger(Info) and logg(Info, "promote to leader")
    // promote
    status = Leader
    voted_for = NullNode
    // re-init peer index bookkeeping
    for peer in peers.values() do
      next_index.update(peer, last_entry().index() + 1)
      match_index.update(peer, 0)
    end
    let t = Timer(_HeartbeatNotify(this), 0, 15_000_000)
    timers(consume t)

  fun ref promote_follower() =>
    logger(Info) and logg(Info, "promote to follower")
    if status is Leader then
      timers.cancel(heartbeat_timer)
    end
    status = Follower
    voted_for = NullNode
    // start election timer
    timeout = ((mt.next() % (max_timeout - min_timeout)) + min_timeout)
    beatTS = Time.nanos()
    let t = Timer(_TimeoutNotify(this),timeout)
    heartbeat_timer = t
    timers(consume t)
    
  be start(nodes: Array[Node tag] iso) =>
    peers = consume nodes
    promote_follower()
