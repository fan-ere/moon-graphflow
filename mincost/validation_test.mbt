///|
fn lcg_next_mc(state : Int64) -> Int64 {
  state * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
}

///|
fn lcg_pick_mc(state : Int64, bound : Int) -> Int {
  (state & 0xFFFFL).to_int() % bound
}

///|
fn has_negative_cycle(n : Int, edges : Array[(Int, Int, Int64, Int64)]) -> Bool {
  // Bellman-Ford from a virtual super source: any further relaxation after
  // n - 1 rounds means a reachable negative cycle.
  let dist : Array[Int64] = Array::make(n, 0L)
  let mut changed = true
  let mut round = 0
  while changed && round < n {
    changed = false
    round += 1
    for e in edges {
      if dist[e.0] + e.3 < dist[e.1] {
        dist[e.1] = dist[e.0] + e.3
        changed = true
      }
    }
  }
  changed
}

///|
fn brute_min_cost_max_flow(
  n : Int,
  edges : Array[(Int, Int, Int64, Int64)],
  s : Int,
  t : Int,
) -> (Int64, Int64) {
  // Enumerate every integral flow vector on a tiny graph, keep the ones that
  // conserve flow, and pick the largest value, cheapest among ties.
  let m = edges.length()
  let flows : Array[Int64] = Array::make(m, 0L)
  let radices : Array[Int64] = Array::make(m, 1L)
  let mut best_flow : Int64 = 0L
  let mut best_cost : Int64 = 0L
  let mut best_found = false
  // Mixed-radix decoding: digit k has base (cap_k + 1), so the enumeration
  // covers every vector (f_0..f_m) with 0 <= f_k <= cap_k exactly once.
  let combos = {
    let mut total : Int64 = 1L
    for k, e in edges {
      radices[k] = e.2 + 1L
      total *= e.2 + 1L
    }
    total
  }
  let mut code : Int64 = 0L
  while code < combos {
    let mut rest = code
    for k in 0..<m {
      flows[k] = rest % radices[k]
      rest /= radices[k]
    }
    let bal : Array[Int64] = Array::make(n, 0L)
    let mut cost : Int64 = 0L
    for i in 0..<m {
      let f = flows[i]
      let e = edges[i]
      if f != 0L {
        bal[e.0] -= f
        bal[e.1] += f
        cost += f * e.3
      }
    }
    let mut ok = true
    let mut v = 0
    while ok && v < n {
      if v != s && v != t && bal[v] != 0L {
        ok = false
      }
      v += 1
    }
    if ok {
      let value = bal[t]
      let better = !best_found || value > best_flow
      let tie = value == best_flow && cost < best_cost
      if better || tie {
        best_flow = value
        best_cost = cost
        best_found = true
      }
    }
    code += 1L
  }
  (best_flow, best_cost)
}

///|
test "randomized cross-check against exhaustive enumeration on 120 instances" {
  let mut seed : Int64 = 4242420000000007L
  let mut checked = 0
  let mut attempts = 0
  while checked < 120 && attempts < 600 {
    attempts += 1
    seed = lcg_next_mc(seed)
    let n = 2 + lcg_pick_mc(seed, 3)
    seed = lcg_next_mc(seed)
    let m = 1 + lcg_pick_mc(seed, 5)
    let builder = unwrap_build(@graph.GraphBuilder::new(n))
    let edges : Array[(Int, Int, Int64, Int64)] = []
    let mut k = 0
    let mut rejected = false
    while k < m && !rejected {
      seed = lcg_next_mc(seed)
      let u = lcg_pick_mc(seed, n)
      seed = lcg_next_mc(seed)
      let v = lcg_pick_mc(seed, n)
      seed = lcg_next_mc(seed)
      let c = 1 + lcg_pick_mc(seed, 3)
      seed = lcg_next_mc(seed)
      let cost = lcg_pick_mc(seed, 7) - 3
      if u == v && cost < 0 {
        // Negative self loops are negative cycles by definition; keep the
        // generated instance inside the documented contract instead.
        rejected = true
      } else {
        let added = builder.add_costed_edge(u, v, c.to_int64(), cost.to_int64())
        assert_eq(added is Ok(_), true)
        edges.push((u, v, c.to_int64(), cost.to_int64()))
      }
      k += 1
    }
    if !rejected && !has_negative_cycle(n, edges) {
      let g = builder.build()
      let sol = unwrap_mc(@mincost.solve_min_cost_max_flow(g, 0, n - 1))
      let expected = brute_min_cost_max_flow(n, edges, 0, n - 1)
      assert_eq(sol.total_flow, expected.0)
      assert_eq(sol.total_cost, expected.1)
      check_mc_conservation(g, sol, 0, n - 1)
      checked += 1
    }
  }
  assert_eq(checked, 120)
}
