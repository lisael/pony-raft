use "collections"

actor _KVStore
  var _data: Map[String, I64] = Map[String, I64]

  be set(key: String, value: I64) =>
    _data.update(key, value)
      
  be get(key: String) =>
    try _data(key) else None end

  be delete(key: String) =>
    try
      (_, let v: I64) = _data.remove(key)
      v
    else
      None
    end
