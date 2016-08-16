use "collections"

type RaftValue is I64
type RaftResult is ( I64 | None )

interface RaftNotifier
  fun ref apply(resp: RaftResult)

actor _KVStore
  var _data: Map[String, RaftValue] = Map[String, RaftValue]

  be set(key: String, value: RaftValue, notify: RaftNotifier iso) =>
    notify(_data.update(key, value))
      
  be get(key: String, notify: RaftNotifier iso) =>
    notify(try _data(key) else None end)

  be delete(key: String, notify: RaftNotifier iso) =>
    notify(try
      (_, let v: RaftValue) = _data.remove(key)
      v
    else
      None
    end)
