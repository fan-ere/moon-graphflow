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
fn unwrap_flow(
  r : Result[@maxflow.FlowSolution, @maxflow.FlowError],
) -> @maxflow.FlowSolution {
  match r {
    Ok(s) => s
    Err(e) => abort("unexpected flow error: \{e.message()}")
  }
}

///|
fn flow_error_message(
  r : Result[@maxflow.FlowSolution, @maxflow.FlowError],
) -> String {
  match r {
    Ok(_) => abort("expected a flow error")
    Err(e) => e.message()
  }
}

///|
fn build_graph(
  n : Int,
  edges : Array[(Int, Int, Int64)],
) -> @graph.FlowGraph raise {
  let builder = unwrap_build(@graph.GraphBuilder::new(n))
  for e in edges {
    assert_eq(builder.add_edge(e.0, e.1, e.2) is Ok(_), true)
  }
  builder.build()
}

///|
test "error cases report exact messages" {
  let g = build_graph(2, [(0, 1, 5L)])
  assert_eq(
    flow_error_message(@maxflow.solve_max_flow(g, -1, 1)),
    "source -1 out of range [0, 2)",
  )
  assert_eq(
    flow_error_message(@maxflow.solve_max_flow(g, 0, 2)),
    "sink 2 out of range [0, 2)",
  )
  assert_eq(
    flow_error_message(@maxflow.solve_max_flow(g, 1, 1)),
    "source and sink must differ, both are 1",
  )
}

///|
test "single chain carries its bottleneck" {
  // 0 -> 1 -> 2 with capacities 3 then 5: the chain is capped at 3.
  let g = build_graph(3, [(0, 1, 3L), (1, 2, 5L)])
  let sol = unwrap_flow(@maxflow.solve_max_flow(g, 0, 2))
  assert_eq(sol.total_flow, 3L)
  assert_eq(sol.edge_flow[0], 3L)
  assert_eq(sol.edge_flow[1], 3L)
  assert_eq(sol.source_side, [0])
}

///|
test "classic network with two paths" {
  // Node 0 feeds 1 and 2; both feed node 3. Widely used textbook instance.
  let g = build_graph(4, [
    (0, 1, 4L),
    (0, 2, 3L),
    (1, 3, 2L),
    (1, 2, 3L),
    (2, 3, 5L),
  ])
  let sol = unwrap_flow(@maxflow.solve_max_flow(g, 0, 3))
  assert_eq(sol.total_flow, 7L)
  // Cut certificate: 0->1 (4) and 0->2 (3) both cross and are saturated.
  assert_eq(sol.source_side, [0])
  assert_eq(sol.edge_flow[0], 4L)
  assert_eq(sol.edge_flow[1], 3L)
}

///|
test "disconnected graph has zero flow and full source side" {
  let g = build_graph(4, [(0, 1, 9L), (2, 3, 9L)])
  let sol = unwrap_flow(@maxflow.solve_max_flow(g, 0, 3))
  assert_eq(sol.total_flow, 0L)
  assert_eq(sol.source_side, [0, 1])
}

///|
test "reverse capacity edges allow rerouting" {
  // 0 -> 1 and 1 -> 0 both exist; flow can use either direction.
  let g = build_graph(3, [(0, 1, 2L), (1, 0, 2L), (1, 2, 2L)])
  let sol = unwrap_flow(@maxflow.solve_max_flow(g, 0, 2))
  assert_eq(sol.total_flow, 2L)
}

///|
test "parallel edges accumulate" {
  let g = build_graph(2, [(0, 1, 2L), (0, 1, 3L), (0, 1, 4L)])
  let sol = unwrap_flow(@maxflow.solve_max_flow(g, 0, 1))
  assert_eq(sol.total_flow, 9L)
  assert_eq(sol.edge_flow[0], 2L)
  assert_eq(sol.edge_flow[1], 3L)
  assert_eq(sol.edge_flow[2], 4L)
}

///|
test "self loops never carry flow" {
  let g = build_graph(2, [(0, 0, 5L), (0, 1, 2L)])
  let sol = unwrap_flow(@maxflow.solve_max_flow(g, 0, 1))
  assert_eq(sol.total_flow, 2L)
  assert_eq(sol.edge_flow[0], 0L)
}

///|
test "diamond with middle bottleneck" {
  let g = build_graph(4, [
    (0, 1, 10L),
    (0, 2, 10L),
    (1, 3, 10L),
    (2, 3, 10L),
    (1, 2, 1L),
  ])
  let sol = unwrap_flow(@maxflow.solve_max_flow(g, 0, 3))
  assert_eq(sol.total_flow, 20L)
}

///|
test "layered network needs multiple dinic phases" {
  let builder = unwrap_build(@graph.GraphBuilder::new(6))
  let layers = [
    (0, 1, 10L),
    (0, 2, 10L),
    (1, 3, 4L),
    (1, 4, 8L),
    (2, 3, 9L),
    (2, 4, 6L),
    (3, 5, 10L),
    (4, 5, 10L),
  ]
  for e in layers {
    assert_eq(builder.add_edge(e.0, e.1, e.2) is Ok(_), true)
  }
  let g = builder.build()
  let sol = unwrap_flow(@maxflow.solve_max_flow(g, 0, 5))
  assert_eq(sol.total_flow, 20L)
  assert_eq(sol.edge_flow[0], 10L)
  assert_eq(sol.edge_flow[1], 10L)
}
