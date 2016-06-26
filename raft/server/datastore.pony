use "collections"

class _KVStore
  var _data: Map[String, I64] = Map[String, I64]

  fun ref set(key: String, value: I64): (I64 | None) =>
    _data.update(key, value)
      
  fun get(key: String): (I64 | None)=>
    try _data(key) else None end

  fun ref delete(key: String): (I64 | None)=>
    try
      (_, let v: I64) = _data.remove(key)
      v
    else
      None
    end
