"""
Package: pony-raft

A pure pony Raft implementation. This was created for educational purpose, as
an example for https://lisael.gitbooks.io/first-ride-with-pony/content/.
"""
actor Main
  """
  Our Main stub. Does nothing interesting, now
  """
  new create(env: Env) =>
    """
    realy nothing interesting, but it's documented, at least.
    """
    env.out.write("Hello, Pony\n")
