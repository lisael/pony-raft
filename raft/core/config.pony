use "logger"
use "options"
use "files"
use "ini"

interface RaftConfig
  fun val get_logger(): Logger[String]

primitive PrintCliUsage
  fun apply(env: Env) =>
    env.out.write("""

raft [--host=HOST] [--port=PORT] [--log-level=LEVEL] [--log-file=FILE]
Starts a raft node

OPTIONS:
  --host=HOST, -h HOST:
    IP address to bind. Default 127.0.0.1 
  --port=PORT, -p PORT:
    listen port. Default is 9876
  --log-level=[fine|info|warn|error], -l [fine|info|warn|error]:
    log level. Default warn is enough for production
  --log-file=FILE, -l FILE:
    Log file. Default is stdout (-)
""")

class CliConfig
  let env: Env
  var host: String = "127.0.0.1"
  var port: String = "9876"
  var log_file: String = "-"
  var _log_stream: OutStream
  var _log_level: LogLevel = Warn
  var err: Bool = false

  new val create(env': Env) =>
    env = env'
    _log_stream = env.out
    let log = StringLogger(_log_level, _log_stream)
    _load_config()
    var options = Options(env.args) +
      ("host", "h", StringArgument) +
      ("port", "p", StringArgument) +
      ("log-level", "l", StringArgument) +
      ("log-file", "f", StringArgument)
    try 
      for opt in options do
        match opt
        | ("host", let arg: String) => host = arg
        | ("port", let arg: String) => port = arg
        | ("log-level", let arg: String) =>
          _log_level = try _parse_log_level(arg) else
            log.log("Error: --log-level must be one of fine, info, warn or error")
            error
          end
        | ("log-file", let arg: String) =>
          _log_stream = match _parse_log_file(arg)
          | let st: OutStream => st
          | let err': String =>
            log.log("Error while opening log file: " + err')
            error
          else _log_stream end
        | let err': ParseError =>
          //err'.report(env.out)
          error
        end
      end
    else
      err = true
    end

  fun val get_logger(): Logger[String] =>
    StringLogger(_log_level, _log_stream)

  fun _get_env(env_var: String) : String =>
    try EnvVars(env.vars())(env_var) else "" end

  fun _parse_log_file(fname: String): (OutStream | String) =>
    if fname == "-" then return env.out end
    try let path = FilePath(env.root as AmbientAuth, fname) end
    "Log file not implemented"

  fun _parse_log_level(lvl: String): LogLevel ? =>
    match lvl.lower()
    | "fine" => Fine
    | "info" => Info
    | "warn" => Warn
    | "error" => Error
    else
      error
    end

  fun ref _load_config() =>
    // first try to load config file from env
    match _get_env("PONY_RAFT_CONFIG")
    | "" => 
      // if not found, load system-wide configuration
      _load_config_file("/etc/pony-raft.ini")
      // ... and then load configuration from users dotfiles
      match _get_env("HOME")
      | "" => None
      | let home: String => _load_config_file( home + "/.pony-raft.ini")
      end
    | let f: String => _load_config_file(f)
    end

  fun ref _load_config_file(fname: String): String =>
    try
      let conf_path = FilePath(env.root as AmbientAuth, fname)
      if not conf_path.exists() then error end
      let conf_file = File(conf_path)
      let conf = IniParse(conf_file.lines())
      try
        let server = conf("server")
        host = try server("host") else host end
        port = try server("port") else port end
        _log_level = try _parse_log_level(server("log-level")) else _log_level end
      end
      ""
    else
      "Cannot read " + fname
    end

