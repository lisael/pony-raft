"""
Package: pony-raft

A pure pony Raft implementation. This was created for educational purpose, as
an example for https://lisael.gitbooks.io/first-ride-with-pony/content/.
"""
use "files"
use "ini"
use "options"
use "logger"
use "raft/core"

actor Main
  """
  Our Main stub. Does nothing interesting, now
  """
  new create(env: Env) =>
    """
    realy nothing interesting, but it's documented, at least.
    """
    let config: CliConfig val = CliConfig(env)
    if config.err then PrintCliUsage(env); return end
    env.out.write("Listening on " + config.host + ":" + config.port + "\n")
    let client = TestClient
    TestCluster(5, config, client)
