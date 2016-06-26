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

class iso _TestKVStoreSet is UnitTest
  fun name():String => "_KVStore.set"

  fun apply(h: TestHelper) =>
    let k = _KVStore
    var result = k.set("test1", 1)
    match result
    | None => None
    | let v: I64 => h.fail("The map should be empty")
    end
    result = k.set("test1", 2)
    match result
    | None => h.fail("There should be a value")
    | let v: I64 => h.assert_eq[I64](v, 1)
    end

class iso _TestKVStoreGet is UnitTest
  fun name():String => "_KVStore.get"

  fun apply(h: TestHelper) =>
    let k = _KVStore
    var result = k.get("test1")
    match result
    | None => None
    | let v: I64 => h.fail("The map should be empty")
    end
    k.set("test1", 1)
    result = k.get("test1")
    match result
    | None => h.fail("There should be a value")
    | let v: I64 => h.assert_eq[I64](v, 1)
    end

class iso _TestKVStoreDelete is UnitTest
  fun name():String => "_KVStore.delete"

  fun apply(h: TestHelper) =>
    let k = _KVStore
    var result = k.delete("test1")
    match result
    | None => None
    | let v: I64 => h.fail("The map should be empty")
    end
