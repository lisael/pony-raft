use "collections"

class _KVStore
  var _data: Map[String, I64] iso = recover iso Map[String, I64] end

  fun iso set(key: String, value: I64) =>
    _data.update(key, value)
      
  fun iso delete(key: String) =>
    try _data.remove(key) else I64(0) end

  fun iso get(key: String) =>
    try _data(key) else 0 end
