///|
pub(all) enum FlowError {
  BadSource(Int, Int)
  BadSink(Int, Int)
  SameSourceSink(Int)
}

///|
pub fn FlowError::message(self : FlowError) -> String {
  match self {
    BadSource(s, n) => "source \{s} out of range [0, \{n})"
    BadSink(t, n) => "sink \{t} out of range [0, \{n})"
    SameSourceSink(x) => "source and sink must differ, both are \{x}"
  }
}

///|
pub struct FlowSolution {
  total_flow : Int64
  edge_flow : Array[Int64]
  source_side : Array[Int]
}

///|
const INF_LEVEL : Int = -1

///|
pub fn solve_max_flow(
  g : @graph.FlowGraph,
  source : Int,
  sink : Int,
) -> Result[FlowSolution, FlowError] {
  if source < 0 || source >= g.node_count {
    return Err(BadSource(source, g.node_count))
  }
  if sink < 0 || sink >= g.node_count {
    return Err(BadSink(sink, g.node_count))
  }
  if source == sink {
    return Err(SameSourceSink(source))
  }
  let n = g.node_count
  let to = g.to
  let nxt = g.next_edge
  let first = g.first
  let slots = g.slot_count
  let cap : Array[Int64] = Array::make(slots, 0L)
  for i in 0..<slots {
    cap[i] = g.cap[i]
  }
  let level : Array[Int] = Array::make(n, INF_LEVEL)
  let queue : Array[Int] = Array::make(n, 0)
  let cur : Array[Int] = Array::make(n, -1)
  let path_edge : Array[Int] = Array::make(n + 1, 0)
  let mut total : Int64 = 0L
  let mut cont = true
  while cont {
    // BFS builds the level graph on the current residual.
    for i in 0..<n {
      level[i] = INF_LEVEL
    }
    level[source] = 0
    let mut head = 0
    let mut tail = 0
    queue[tail] = source
    tail += 1
    while head < tail {
      let u = queue[head]
      head += 1
      let mut e = first[u]
      while e != -1 {
        let v = to[e]
        if cap[e] > 0L && level[v] == INF_LEVEL {
          level[v] = level[u] + 1
          queue[tail] = v
          tail += 1
        }
        e = nxt[e]
      }
    }
    if level[sink] == INF_LEVEL {
      cont = false
    } else {
      // Blocking flow with an explicit path stack; no recursion anywhere.
      for i in 0..<n {
        cur[i] = first[i]
      }
      let mut plen = 0
      let mut u = source
      while true {
        if u == sink {
          let mut b = cap[path_edge[0]]
          for k in 1..<plen {
            let c = cap[path_edge[k]]
            if c < b {
              b = c
            }
          }
          for k in 0..<plen {
            let e = path_edge[k]
            cap[e] -= b
            cap[e ^ 1] += b
          }
          total += b
          // Retreat to the first saturated edge; earlier edges keep flow.
          let mut cut = 0
          for k in 0..<plen {
            if cap[path_edge[k]] == 0L {
              cut = k
              break
            }
          }
          u = to[path_edge[cut] ^ 1]
          plen = cut
        } else {
          let mut e = cur[u]
          while e != -1 && (cap[e] <= 0L || level[to[e]] != level[u] + 1) {
            e = nxt[e]
          }
          cur[u] = e
          if e == -1 {
            if u == source {
              break
            }
            plen -= 1
            let pe = path_edge[plen]
            u = to[pe ^ 1]
            cur[u] = nxt[pe]
          } else {
            path_edge[plen] = e
            plen += 1
            u = to[e]
          }
        }
      }
    }
  }
  // Nodes still reachable from the source form the source side of a minimum
  // s-t cut: every crossing edge is saturated and every incoming edge empty.
  let source_side : Array[Int] = []
  for i in 0..<n {
    if level[i] != INF_LEVEL {
      source_side.push(i)
    }
  }
  let edge_flow : Array[Int64] = Array::make(g.edge_count, 0L)
  for k in 0..<g.edge_count {
    edge_flow[k] = g.init_cap[k] - cap[k * 2]
  }
  Ok({ total_flow: total, edge_flow, source_side, })
}
