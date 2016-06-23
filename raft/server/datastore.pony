use "collections"

class _KVStore
  var _data: Map[String, I64] = Map[String, I64]

  fun set(key: String, value: I64) =>
    _data.update(key, value)
      
  fun delete(key: String) =>
    try _data.remove(key) else I64(0) end

  fun get(key: String) =>
    try _data(key) else 0 end
