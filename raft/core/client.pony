interface RaftClient
  be start(nodes: Array[Node tag] iso)

actor TestClient is RaftClient
  be start(nodes: Array[Node tag] iso) => None
