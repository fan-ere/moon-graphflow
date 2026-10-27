///|
pub(all) enum MinCostError {
  BadSource(Int, Int)
  BadSink(Int, Int)
  SameSourceSink(Int)
  BadAmount(Int64)
  NegativeCycle
  InsufficientFlow(Int64, Int64)
  CostOverflow
}

///|
pub fn MinCostError::message(self : MinCostError) -> String {
  match self {
    BadSource(s, n) => "source \{s} out of range [0, \{n})"
    BadSink(t, n) => "sink \{t} out of range [0, \{n})"
    SameSourceSink(x) => "source and sink must differ, both are \{x}"
    BadAmount(a) => "required flow must be non-negative, got \{a}"
    NegativeCycle => "the residual network contains a negative cost cycle"
    InsufficientFlow(reached, wanted) =>
      "only \{reached} of \{wanted} flow units can reach the sink"
    CostOverflow => "the accumulated cost exceeds the bounded cost limit"
  }
}

///|
pub struct MinCostSolution {
  total_flow : Int64
  total_cost : Int64
  edge_flow : Array[Int64]
}

///|
const INF_COST : Int64 = 4_611_686_018_427_387_904L

///|
const COST_SUM_LIMIT : Int64 = 2_000_000_000_000_000_000L

///|
priv struct MinHeap {
  mut keys : Array[Int64]
  mut nodes : Array[Int]
  mut size : Int
}

///|
fn MinHeap::new(capacity : Int) -> MinHeap {
  {
    keys: Array::make(capacity + 1, 0L),
    nodes: Array::make(capacity + 1, 0),
    size: 0,
  }
}

///|
fn MinHeap::less(self : MinHeap, a : Int, b : Int) -> Bool {
  let ka = self.keys[a]
  let kb = self.keys[b]
  if ka != kb {
    ka < kb
  } else {
    self.nodes[a] < self.nodes[b]
  }
}

///|
fn MinHeap::swap(self : MinHeap, a : Int, b : Int) -> Unit {
  let k = self.keys[a]
  self.keys[a] = self.keys[b]
  self.keys[b] = k
  let n = self.nodes[a]
  self.nodes[a] = self.nodes[b]
  self.nodes[b] = n
}

///|
fn MinHeap::push(self : MinHeap, key : Int64, node : Int) -> Unit {
  let mut i = self.size
  self.size += 1
  // The heap arrays are sized for the worst case of pushes per phase; growth
  // is not needed because callers rebuild the heap for every Dijkstra run.
  if self.size >= self.keys.length() {
    let nk : Array[Int64] = Array::make(self.keys.length() * 2 + 1, 0L)
    let nn : Array[Int] = Array::make(self.keys.length() * 2 + 1, 0)
    for j in 0..<self.size {
      nk[j] = self.keys[j]
      nn[j] = self.nodes[j]
    }
    self.keys = nk
    self.nodes = nn
  }
  self.keys[i] = key
  self.nodes[i] = node
  while i > 0 {
    let parent = (i - 1) / 2
    if self.less(i, parent) {
      self.swap(i, parent)
      i = parent
    } else {
      break
    }
  }
}

///|
fn MinHeap::pop(self : MinHeap) -> Unit {
  self.size -= 1
  self.keys[0] = self.keys[self.size]
  self.nodes[0] = self.nodes[self.size]
  let mut i = 0
  while true {
    let l = i * 2 + 1
    let r = i * 2 + 2
    let mut m = i
    if l < self.size && self.less(l, m) {
      m = l
    }
    if r < self.size && self.less(r, m) {
      m = r
    }
    if m == i {
      break
    }
    self.swap(i, m)
    i = m
  }
}

///|
fn MinHeap::top_key(self : MinHeap) -> Int64 {
  self.keys[0]
}

///|
fn MinHeap::top_node(self : MinHeap) -> Int {
  self.nodes[0]
}

///|
fn checked_cost_add(acc : Int64, product : Int64) -> Result[Int64, Unit] {
  if product >= 0L {
    if acc > COST_SUM_LIMIT - product {
      Err(())
    } else {
      Ok(acc + product)
    }
  } else if acc < -COST_SUM_LIMIT - product {
    Err(())
  } else {
    Ok(acc + product)
  }
}

///|
fn run_min_cost(
  g : @graph.FlowGraph,
  source : Int,
  sink : Int,
  amount : Int64,
) -> Result[(Int64, Array[Int64]), MinCostError] {
  // amount is the flow target; the unbounded variant passes a value that can
  // never be reached, which turns the same loop into min-cost max-flow.
  let n = g.node_count
  let to = g.to
  let nxt = g.next_edge
  let first = g.first
  let slots = g.slot_count
  let cap : Array[Int64] = Array::make(slots, 0L)
  for i in 0..<slots {
    cap[i] = g.cap[i]
  }
  let cost = g.cost
  // Initial potentials: shortest real distances from a virtual super source
  // connected to every node with a zero cost edge, computed with SPFA. This
  // keeps reduced costs non-negative even with negative edge costs, and the
  // relaxation counter doubles as a negative cycle detector.
  let h : Array[Int64] = Array::make(n, 0L)
  let in_queue : Array[Bool] = Array::make(n, false)
  let relaxations : Array[Int] = Array::make(n, 0)
  let spfa : Array[Int] = []
  for v in 0..<n {
    spfa.push(v)
    in_queue[v] = true
  }
  let mut head = 0
  while head < spfa.length() {
    let u = spfa[head]
    head += 1
    in_queue[u] = false
    let mut e = first[u]
    while e != -1 {
      if cap[e] > 0L {
        let v = to[e]
        let candidate = h[u] + cost[e]
        if candidate < h[v] {
          h[v] = candidate
          if !in_queue[v] {
            in_queue[v] = true
            spfa.push(v)
            relaxations[v] += 1
            if relaxations[v] > n {
              return Err(NegativeCycle)
            }
          }
        }
      }
      e = nxt[e]
    }
  }
  let dist : Array[Int64] = Array::make(n, 0L)
  let visited : Array[Bool] = Array::make(n, false)
  let parent_slot : Array[Int] = Array::make(n, -1)
  let heap = MinHeap::new(n + 1)
  let mut pushed : Int64 = 0L
  while pushed < amount {
    // Dijkstra on reduced costs from the source to the sink.
    for i in 0..<n {
      dist[i] = INF_COST
      visited[i] = false
      parent_slot[i] = -1
    }
    dist[source] = 0L
    heap.push(0L, source)
    while heap.size > 0 {
      let u = heap.top_node()
      let _ = heap.top_key()
      heap.pop()
      if visited[u] {
        continue
      }
      visited[u] = true
      let mut e = first[u]
      while e != -1 {
        if cap[e] > 0L {
          let v = to[e]
          if !visited[v] {
            let reduced = cost[e] + h[u] - h[v]
            let candidate = dist[u] + reduced
            if candidate < dist[v] {
              dist[v] = candidate
              parent_slot[v] = e
              heap.push(candidate, v)
            }
          }
        }
        e = nxt[e]
      }
    }
    if dist[sink] >= INF_COST {
      break
    }
    let mut b = amount - pushed
    let mut v = sink
    while v != source {
      let e = parent_slot[v]
      let c = cap[e]
      if c < b {
        b = c
      }
      v = to[e ^ 1]
    }
    v = sink
    while v != source {
      let e = parent_slot[v]
      cap[e] -= b
      cap[e ^ 1] += b
      v = to[e ^ 1]
    }
    pushed += b
    // Dual update keeps reduced costs non-negative for the next phase.
    for i in 0..<n {
      if dist[i] < INF_COST {
        h[i] += dist[i]
      } else {
        h[i] += dist[sink]
      }
    }
  }
  let edge_flow : Array[Int64] = Array::make(g.edge_count, 0L)
  for k in 0..<g.edge_count {
    edge_flow[k] = g.init_cap[k] - cap[k * 2]
  }
  Ok((pushed, edge_flow))
}

///|
pub fn solve_min_cost_max_flow(
  g : @graph.FlowGraph,
  source : Int,
  sink : Int,
) -> Result[MinCostSolution, MinCostError] {
  finish_min_cost(g, source, sink, INF_COST)
}

///|
pub fn solve_min_cost_flow(
  g : @graph.FlowGraph,
  source : Int,
  sink : Int,
  amount : Int64,
) -> Result[MinCostSolution, MinCostError] {
  finish_min_cost(g, source, sink, amount)
}

///|
fn finish_min_cost(
  g : @graph.FlowGraph,
  source : Int,
  sink : Int,
  amount : Int64,
) -> Result[MinCostSolution, MinCostError] {
  if source < 0 || source >= g.node_count {
    return Err(BadSource(source, g.node_count))
  }
  if sink < 0 || sink >= g.node_count {
    return Err(BadSink(sink, g.node_count))
  }
  if source == sink {
    return Err(SameSourceSink(source))
  }
  if amount < 0L {
    return Err(BadAmount(amount))
  }
  if amount == 0L {
    let edge_flow : Array[Int64] = Array::make(g.edge_count, 0L)
    return Ok({ total_flow: 0L, total_cost: 0L, edge_flow, })
  }
  let pair = run_min_cost(g, source, sink, amount)
  match pair {
    Err(e) => Err(e)
    Ok((flow, edge_flow)) => {
      // The unbounded variant never reports a shortfall: it always pushes
      // the maximum the network allows. Exact amounts must be reached.
      if amount != INF_COST && flow < amount {
        return Err(InsufficientFlow(flow, amount))
      }
      // Total cost as the exact sum of per-edge contributions; each product
      // is bounded by CAP_LIMIT * COST_LIMIT and the accumulation is checked.
      let mut total_cost : Int64 = 0L
      for k in 0..<g.edge_count {
        let f = edge_flow[k]
        if f != 0L {
          let product = f * g.cost[k * 2]
          match checked_cost_add(total_cost, product) {
            Err(_) => return Err(CostOverflow)
            Ok(sum) => total_cost = sum
          }
        }
      }
      Ok({ total_flow: flow, total_cost, edge_flow, })
    }
  }
}
