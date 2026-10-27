///|
fn lcg_next(state : Int64) -> Int64 {
  state * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
}

///|
fn lcg_pick(state : Int64, bound : Int) -> Int {
  (state & 0xFFFFL).to_int() % bound
}

///|
fn ek_max_flow(
  n : Int,
  edges : Array[(Int, Int, Int64)],
  s : Int,
  t : Int,
) -> Int64 {
  // Reference implementation: BFS augmenting paths on a dense matrix.
  let cap : Array[Int64] = Array::make(n * n, 0L)
  for e in edges {
    cap[e.0 * n + e.1] += e.2
  }
  let parent = Array::make(n, -1)
  let visited = Array::make(n, false)
  let queue = Array::make(n, 0)
  let mut total : Int64 = 0L
  while true {
    for i in 0..<n {
      visited[i] = false
      parent[i] = -1
    }
    visited[s] = true
    let mut head = 0
    let mut tail = 0
    queue[tail] = s
    tail += 1
    let mut found = false
    while head < tail && !found {
      let u = queue[head]
      head += 1
      for v in 0..<n {
        if !visited[v] && cap[u * n + v] > 0L {
          visited[v] = true
          parent[v] = u
          queue[tail] = v
          tail += 1
          if v == t {
            found = true
            break
          }
        }
      }
    }
    if !found {
      return total
    }
    let mut b = cap[parent[t] * n + t]
    let mut v = t
    while v != s {
      let p = parent[v]
      let c = cap[p * n + v]
      if c < b {
        b = c
      }
      v = p
    }
    v = t
    while v != s {
      let p = parent[v]
      cap[p * n + v] -= b
      cap[v * n + p] += b
      v = p
    }
    total += b
  }
  total
}

///|
fn check_conservation(
  g : @graph.FlowGraph,
  sol : @maxflow.FlowSolution,
  s : Int,
  t : Int,
) -> Unit raise {
  let bal : Array[Int64] = Array::make(g.node_count, 0L)
  for k in 0..<g.edge_count {
    let f = sol.edge_flow[k]
    if f != 0L {
      let spec = g.spec(k)
      bal[spec.from] -= f
      bal[spec.to] += f
    }
  }
  for v in 0..<g.node_count {
    if v != s && v != t {
      assert_eq(bal[v], 0L)
    }
  }
  assert_eq(bal[s] + sol.total_flow, 0L)
  assert_eq(bal[t], sol.total_flow)
}

///|
fn check_cut_certificate(
  g : @graph.FlowGraph,
  sol : @maxflow.FlowSolution,
  s : Int,
  t : Int,
) -> Unit raise {
  let in_side : Array[Bool] = Array::make(g.node_count, false)
  for x in sol.source_side {
    in_side[x] = true
  }
  assert_eq(in_side[s], true)
  assert_eq(in_side[t], false)
  let mut crossing : Int64 = 0L
  for k in 0..<g.edge_count {
    let spec = g.spec(k)
    if in_side[spec.from] && !in_side[spec.to] {
      assert_eq(sol.edge_flow[k], spec.capacity)
      crossing += spec.capacity
    }
    if !in_side[spec.from] && in_side[spec.to] {
      assert_eq(sol.edge_flow[k], 0L)
    }
  }
  assert_eq(crossing, sol.total_flow)
}

///|
test "randomized cross-check against the bfs reference on 80 instances" {
  let mut seed : Int64 = 88172645463325252L
  for _iter in 0..<80 {
    seed = lcg_next(seed)
    let n = 2 + lcg_pick(seed, 10)
    seed = lcg_next(seed)
    let m = lcg_pick(seed, 25)
    let builder = unwrap_build(@graph.GraphBuilder::new(n))
    let edges : Array[(Int, Int, Int64)] = []
    for _k in 0..<m {
      seed = lcg_next(seed)
      let u = lcg_pick(seed, n)
      seed = lcg_next(seed)
      let v = lcg_pick(seed, n)
      seed = lcg_next(seed)
      let c = 1 + lcg_pick(seed, 20)
      assert_eq(builder.add_edge(u, v, c.to_int64()) is Ok(_), true)
      edges.push((u, v, c.to_int64()))
    }
    let g = builder.build()
    let sol = unwrap_flow(@maxflow.solve_max_flow(g, 0, n - 1))
    let expected = ek_max_flow(n, edges, 0, n - 1)
    assert_eq(sol.total_flow, expected)
    check_conservation(g, sol, 0, n - 1)
    check_cut_certificate(g, sol, 0, n - 1)
  }
}

///|
test "same graph solved twice gives the identical answer" {
  let g = build_graph(4, [(0, 1, 4L), (0, 2, 3L), (1, 3, 2L), (2, 3, 5L)])
  let a = unwrap_flow(@maxflow.solve_max_flow(g, 0, 3))
  let b = unwrap_flow(@maxflow.solve_max_flow(g, 0, 3))
  assert_eq(a.total_flow, b.total_flow)
  assert_eq(a.edge_flow, b.edge_flow)
  assert_eq(a.source_side, b.source_side)
}

///|
test "flow into the sink equals zero when the sink has no outgoing edges" {
  let g = build_graph(3, [(0, 1, 5L), (1, 2, 5L), (2, 1, 0L)])
  let sol = unwrap_flow(@maxflow.solve_max_flow(g, 0, 2))
  assert_eq(sol.total_flow, 5L)
  assert_eq(sol.edge_flow[2], 0L)
}
