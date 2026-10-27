///|
fn unwrap_build(
  b : Result[@graph.GraphBuilder, @graph.BuildError],
) -> @graph.GraphBuilder {
  match b {
    Ok(builder) => builder
    Err(e) => abort("unexpected build error: \{e.message()}")
  }
}

///|
fn unwrap_mc(
  r : Result[@mincost.MinCostSolution, @mincost.MinCostError],
) -> @mincost.MinCostSolution {
  match r {
    Ok(s) => s
    Err(e) => abort("unexpected min cost error: \{e.message()}")
  }
}

///|
fn mc_error_message(
  r : Result[@mincost.MinCostSolution, @mincost.MinCostError],
) -> String {
  match r {
    Ok(_) => abort("expected a min cost error")
    Err(e) => e.message()
  }
}

///|
fn build_costed(
  n : Int,
  edges : Array[(Int, Int, Int64, Int64)],
) -> @graph.FlowGraph raise {
  let builder = unwrap_build(@graph.GraphBuilder::new(n))
  for e in edges {
    assert_eq(builder.add_costed_edge(e.0, e.1, e.2, e.3) is Ok(_), true)
  }
  builder.build()
}

///|
fn check_mc_conservation(
  g : @graph.FlowGraph,
  sol : @mincost.MinCostSolution,
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
test "min cost error messages" {
  let g = build_costed(2, [(0, 1, 5L, 1L)])
  assert_eq(
    mc_error_message(@mincost.solve_min_cost_max_flow(g, -1, 1)),
    "source -1 out of range [0, 2)",
  )
  assert_eq(
    mc_error_message(@mincost.solve_min_cost_max_flow(g, 0, 2)),
    "sink 2 out of range [0, 2)",
  )
  assert_eq(
    mc_error_message(@mincost.solve_min_cost_max_flow(g, 1, 1)),
    "source and sink must differ, both are 1",
  )
  assert_eq(
    mc_error_message(@mincost.solve_min_cost_flow(g, 0, 1, -3L)),
    "required flow must be non-negative, got -3",
  )
}

///|
test "zero amount returns a zero solution" {
  let g = build_costed(3, [(0, 1, 5L, 2L), (1, 2, 5L, 2L)])
  let sol = unwrap_mc(@mincost.solve_min_cost_flow(g, 0, 2, 0L))
  assert_eq(sol.total_flow, 0L)
  assert_eq(sol.total_cost, 0L)
  assert_eq(sol.edge_flow, [0L, 0L])
}

///|
test "textbook two path network picks the cheap route first" {
  // 0 -> 1 (cap 3, cost 1), 0 -> 2 (cap 2, cost 3),
  // 1 -> 3 (cap 2, cost 1), 2 -> 3 (cap 3, cost 1).
  // The network passes 2 units through node 1 (2 per unit) and 2 units
  // through node 2 (4 per unit) for a max flow of 4 at cost 12.
  let g = build_costed(4, [
    (0, 1, 3L, 1L),
    (0, 2, 2L, 3L),
    (1, 3, 2L, 1L),
    (2, 3, 3L, 1L),
  ])
  let sol = unwrap_mc(@mincost.solve_min_cost_max_flow(g, 0, 3))
  assert_eq(sol.total_flow, 4L)
  assert_eq(sol.total_cost, 12L)
  assert_eq(sol.edge_flow, [2L, 2L, 2L, 2L])
  check_mc_conservation(g, sol, 0, 3)
}

///|
test "negative edge costs are handled without negative cycles" {
  // Route via the expensive-in-capacity but negative-cost middle edge.
  let g = build_costed(4, [
    (0, 1, 2L, -2L),
    (1, 3, 2L, 2L),
    (0, 2, 2L, 4L),
    (2, 3, 2L, 4L),
  ])
  let sol = unwrap_mc(@mincost.solve_min_cost_max_flow(g, 0, 3))
  assert_eq(sol.total_flow, 4L)
  assert_eq(sol.total_cost, 16L)
  assert_eq(sol.edge_flow, [2L, 2L, 2L, 2L])
}

///|
test "exact amount mode stops before saturating the network" {
  // 0 -> 1 (cap 10, cost 1), 1 -> 2 (cap 10, cost 1): asking for 4 units
  // costs 2 per unit, i.e. 8 in total, even though 10 would be feasible.
  let g = build_costed(3, [(0, 1, 10L, 1L), (1, 2, 10L, 1L)])
  let sol = unwrap_mc(@mincost.solve_min_cost_flow(g, 0, 2, 4L))
  assert_eq(sol.total_flow, 4L)
  assert_eq(sol.total_cost, 8L)
  assert_eq(sol.edge_flow, [4L, 4L])
}

///|
test "insufficient amount reports what could be reached" {
  let g = build_costed(3, [(0, 1, 2L, 1L), (1, 2, 1L, 1L)])
  match @mincost.solve_min_cost_flow(g, 0, 2, 5L) {
    Err(e) =>
      assert_eq(e.message(), "only 1 of 5 flow units can reach the sink")
    Ok(_) => fail("expected InsufficientFlow")
  }
}

///|
test "negative cost self loop is reported as a negative cycle" {
  let g = build_costed(2, [(0, 1, 3L, 1L), (1, 1, 3L, -1L)])
  match @mincost.solve_min_cost_max_flow(g, 0, 1) {
    Err(e) =>
      assert_eq(
        e.message(),
        "the residual network contains a negative cost cycle",
      )
    Ok(_) => fail("expected NegativeCycle")
  }
}

///|
test "cost accumulation beyond the bounded limit is refused" {
  // Three parallel chains, each able to push 1e9 units at cost 1e9 per unit.
  let builder = unwrap_build(@graph.GraphBuilder::new(8))
  let mut i = 0
  while i < 3 {
    assert_eq(
      builder.add_costed_edge(0, 1 + i, 1_000_000_000L, 1_000_000_000L) is Ok(_),
      true,
    )
    assert_eq(
      builder.add_costed_edge(1 + i, 7, 1_000_000_000L, 1_000_000_000L) is Ok(_),
      true,
    )
    i += 1
  }
  let g = builder.build()
  match @mincost.solve_min_cost_max_flow(g, 0, 7) {
    Err(e) =>
      assert_eq(
        e.message(),
        "the accumulated cost exceeds the bounded cost limit",
      )
    Ok(_) => fail("expected CostOverflow")
  }
}

///|
test "zero cost graph maximizes plain flow" {
  // 0 -> 1 (cap 4) can only forward 2 units because 1 -> 3 is capped at 2,
  // while 0 -> 2 forwards its full 3 units: max flow is 5 at cost 0.
  let g = build_costed(4, [
    (0, 1, 4L, 0L),
    (0, 2, 3L, 0L),
    (1, 3, 2L, 0L),
    (2, 3, 5L, 0L),
  ])
  let sol = unwrap_mc(@mincost.solve_min_cost_max_flow(g, 0, 3))
  assert_eq(sol.total_flow, 5L)
  assert_eq(sol.total_cost, 0L)
}
