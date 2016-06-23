"""
Package: pony-raft

A pure pony Raft implementation. This was created for educational purpose, as
an example for https://lisael.gitbooks.io/first-ride-with-pony/content/.
"""
actor Main
  new create(env: Env) =>
    env.out.write("Hello, Pony\n")
