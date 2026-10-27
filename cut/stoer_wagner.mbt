///|
pub const CUT_NODE_LIMIT : Int = 600

///|
pub(all) enum CutError {
  TooManyNodesForCut(Int, Int)
}

///|
pub fn CutError::message(self : CutError) -> String {
  match self {
    TooManyNodesForCut(got, limit) =>
      "global min cut supports at most \{limit} nodes, got \{got}"
  }
}

///|
pub struct GlobalMinCut {
  cut_weight : Int64
  side_a : Array[Int]
  side_b : Array[Int]
}

///|
pub fn global_min_cut(g : @graph.FlowGraph) -> Result[GlobalMinCut, CutError] {
  let n = g.node_count
  if n > CUT_NODE_LIMIT {
    return Err(TooManyNodesForCut(n, CUT_NODE_LIMIT))
  }
  // Dense undirected weight matrix; parallel edges add up, self loops are
  // ignored because they can never cross a cut.
  let w : Array[Int64] = Array::make(n * n, 0L)
  for k in 0..<g.edge_count {
    let spec = g.spec(k)
    if spec.from != spec.to {
      w[spec.from * n + spec.to] += spec.capacity
      w[spec.to * n + spec.from] += spec.capacity
    }
  }
  let alive : Array[Bool] = Array::make(n, true)
  let lists : Array[Array[Int]] = Array::make(n, [])
  for i in 0..<n {
    lists[i] = [i]
  }
  let in_a : Array[Bool] = Array::make(n, false)
  let arr : Array[Int64] = Array::make(n, 0L)
  let best_side : Array[Int] = []
  let mut best : Int64 = 0L
  let mut alive_count = n
  while alive_count > 1 {
    // Maximum adjacency scan: repeatedly take the most strongly connected
    // remaining vertex; the last one defines the cut of this phase.
    for i in 0..<n {
      in_a[i] = false
      arr[i] = 0L
    }
    let mut prev = -1
    let mut last = -1
    for _step in 0..<alive_count {
      let mut sel = -1
      for v in 0..<n {
        if alive[v] && !in_a[v] {
          if sel == -1 || arr[v] > arr[sel] {
            sel = v
          }
        }
      }
      in_a[sel] = true
      prev = last
      last = sel
      for v in 0..<n {
        if alive[v] && !in_a[v] {
          arr[v] += w[sel * n + v]
        }
      }
    }
    if best_side.length() == 0 || arr[last] < best {
      best = arr[last]
      best_side.clear()
      for x in lists[last] {
        best_side.push(x)
      }
    }
    // Merge the last vertex into the runner-up.
    for v in 0..<n {
      if alive[v] && v != last && v != prev {
        w[prev * n + v] += w[last * n + v]
        w[v * n + prev] += w[last * n + v]
      }
    }
    for x in lists[last] {
      lists[prev].push(x)
    }
    alive[last] = false
    alive_count -= 1
  }
  let in_best : Array[Bool] = Array::make(n, false)
  for x in best_side {
    in_best[x] = true
  }
  let side_b : Array[Int] = []
  for i in 0..<n {
    if !in_best[i] {
      side_b.push(i)
    }
  }
  Ok({ cut_weight: best, side_a: best_side, side_b, })
}
