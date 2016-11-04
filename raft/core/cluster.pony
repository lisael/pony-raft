use "raft"
use "collections"

interface Cluster
  be ready(n: Node tag)

actor TestCluster
  let n: USize
  let nodes: Array[Node tag] = Array[Node tag]
  let _client: RaftClient tag

  new create(num: USize, config: RaftConfig val, client: TestClient tag) =>
    n = num
    _client = client
    for i in Range(0, n) do
      MainNode(i.string(), config.get_logger(), this)
    end

  be ready(n': Node tag) =>
    nodes.push(n')
    if nodes.size() == n then
      for node in nodes.values() do
        let clone = recover Array[Node tag] end
        for node' in nodes.values() do
          if node' isnt node then
            clone.push(node')
          end
        end
        node.start(consume clone)
      end
      let clone = recover Array[Node tag] end
      for node in nodes.values() do
        for node' in nodes.values() do
            clone.push(node')
          end
        end
      _client.start(consume clone)
    end
