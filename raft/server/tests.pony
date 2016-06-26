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

class iso _TestKVStoreGet is UnitTest
  fun name():String => "_KVStore.get"

  fun apply(h: TestHelper) =>
    let k = _KVStore
    var result = k.get("test1")

class iso _TestKVStoreDelete is UnitTest
  fun name():String => "_KVStore.delete"

  fun apply(h: TestHelper) =>
    let k = _KVStore
    var result = k.delete("test1")
