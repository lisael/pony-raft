use "ponytest"

class Tests is TestList 
  new create() =>
    None

  new make() =>
    None

  fun tag tests(test: PonyTest) =>
    this._test_vkstore(test)

  fun tag _test_vkstore(test: PonyTest) =>
    test(_TestKVStoreSet)
    test(_TestKVStoreGet)
    test(_TestKVStoreDelete)


class _TestNotifier is RaftNotifier
  let _h: TestHelper
  let _expected: RaftResult
  let _complete: Bool
  new iso create(h: TestHelper, expected: RaftResult, complete: Bool = false) =>
    _h = h
    _expected = expected
    _complete = complete

  fun ref apply(result: RaftResult) =>
    match result
    | None => match _expected
      | None => None
      | let v: I64 => _h.fail("got None, expected " + v.string())
      end
    | let i: I64 => match _expected
      | None => _h.fail("got " + i.string() + " expected None")
      | let j: I64 => _h.assert_eq[I64](i,j)
      end
    end
    if _complete then _h.complete(true) end


class iso _TestKVStoreSet is UnitTest
  fun name():String => "_KVStore.set"

  fun apply(h: TestHelper) =>
    let k = _KVStore
    // add a value
    k.set("test1", 1, _TestNotifier(h, None))
    // should be 1
    k.get("test1", _TestNotifier(h, 1))
    // change the value. set returns the old value
    k.set("test1", 2, _TestNotifier(h, 1))
    // should be 2
    k.get("test1", _TestNotifier(h, 2, true))
    h.long_test(500_000_000)


class iso _TestKVStoreGet is UnitTest
  fun name():String => "_KVStore.get"

  fun apply(h: TestHelper) =>
    let k = _KVStore
    // empty key returns None
    k.get("test1", _TestNotifier(h, None))
    // add a value
    k.set("test1", 1, _TestNotifier(h, None))
    // should be 1, now.
    k.get("test1", _TestNotifier(h, 1))
    // twice, get doesn't consume the value
    k.get("test1", _TestNotifier(h, 1, true))
    h.long_test(500_000_000)


class iso _TestKVStoreDelete is UnitTest
  fun name():String => "_KVStore.delete"

  fun apply(h: TestHelper) =>
    h.log("Created")
    let k = _KVStore
    // empty key returns None
    // h.log("Delete empty")
    k.delete("test1", _TestNotifier(h, None))
    // add a value
    // h.log("Set")
    k.set("test1", 1, _TestNotifier(h, None))
    // should be 1, now.
    // h.log("Get")
    k.get("test1", _TestNotifier(h, 1))
    // empty key returns None
    // h.log("Delete")
    k.delete("test1", _TestNotifier(h, 1, true))
    h.long_test(500_000_000)
