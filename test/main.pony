use "ponytest"
use server = "raft/server"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    server.Tests.tests(test)
