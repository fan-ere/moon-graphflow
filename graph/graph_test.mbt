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
test "builder rejects node counts outside the bounded range" {
  match @graph.GraphBuilder::new(1) {
    Err(e) => assert_eq(e.message(), "node count must be at least 2, got 1")
    Ok(_) => fail("expected TooFewNodes")
  }
  let n = @graph.NODE_LIMIT + 1
  match @graph.GraphBuilder::new(n) {
    Err(e) =>
      assert_eq(
        e.message(),
        "node count \{n} exceeds the limit \{@graph.NODE_LIMIT}",
      )
    Ok(_) => fail("expected TooManyNodes")
  }
  assert_eq(@graph.GraphBuilder::new(4) is Ok(_), true)
}

///|
test "builder validates node ids capacities and costs" {
  let builder = unwrap_build(@graph.GraphBuilder::new(3))
  match builder.add_edge(-1, 2, 5L) {
    Err(e) => assert_eq(e.message(), "node id -1 out of range [0, 3)")
    Ok(_) => fail("expected BadNode")
  }
  match builder.add_edge(0, 3, 5L) {
    Err(e) => assert_eq(e.message(), "node id 3 out of range [0, 3)")
    Ok(_) => fail("expected BadNode")
  }
  match builder.add_edge(0, 1, -1L) {
    Err(e) =>
      assert_eq(
        e.message(),
        "edge capacity -1 must be within [0, \{@graph.CAP_LIMIT}]",
      )
    Ok(_) => fail("expected BadCapacity")
  }
  let bad_cost = @graph.COST_LIMIT + 1L
  match builder.add_costed_edge(0, 1, 5L, bad_cost) {
    Err(e) =>
      assert_eq(
        e.message(),
        "edge cost \{bad_cost} must be within [-\{@graph.COST_LIMIT}, \{@graph.COST_LIMIT}]",
      )
    Ok(_) => fail("expected BadCost")
  }
  assert_eq(builder.add_edge(0, 1, 5L) is Ok(_), true)
  assert_eq(builder.edge_count(), 1)
}

///|
test "edge limit is enforced" {
  let builder = unwrap_build(@graph.GraphBuilder::new(2))
  // Two nodes, alternate directions to stay within the range checks.
  let mut i = 0
  while i < @graph.EDGE_LIMIT {
    if i % 2 == 0 {
      assert_eq(builder.add_edge(0, 1, 1L) is Ok(_), true)
    } else {
      assert_eq(builder.add_edge(1, 0, 1L) is Ok(_), true)
    }
    i += 1
  }
  match builder.add_edge(0, 1, 1L) {
    Err(e) =>
      assert_eq(
        e.message(),
        "edge \{@graph.EDGE_LIMIT} would exceed the edge limit \{@graph.EDGE_LIMIT}",
      )
    Ok(_) => fail("expected TooManyEdges")
  }
}

///|
test "build produces paired residual slots and readable specs" {
  let builder = unwrap_build(@graph.GraphBuilder::new(3))
  assert_eq(builder.add_costed_edge(0, 2, 7L, 3L) is Ok(_), true)
  assert_eq(builder.add_edge(2, 1, 4L) is Ok(_), true)
  let g = builder.build()
  assert_eq(g.node_count, 3)
  assert_eq(g.edge_count, 2)
  assert_eq(g.slot_count, 4)
  let s0 = g.spec(0)
  assert_eq(s0.from, 0)
  assert_eq(s0.to, 2)
  assert_eq(s0.capacity, 7L)
  assert_eq(s0.cost, 3L)
  let s1 = g.spec(1)
  assert_eq(s1.from, 2)
  assert_eq(s1.to, 1)
  assert_eq(s1.capacity, 4L)
  assert_eq(s1.cost, 0L)
  // Reverse slot mirrors the forward endpoint and negates the cost.
  assert_eq(g.to[1], 0)
  assert_eq(g.cap[1], 0L)
  assert_eq(g.cost[1], -3L)
  assert_eq(g.to[3], 2)
  assert_eq(g.cost[3], 0L)
  // Initial capacities are kept for per-edge flow reporting.
  assert_eq(g.init_cap[0], 7L)
  assert_eq(g.init_cap[1], 4L)
}

///|
test "self loops and parallel edges are accepted" {
  let builder = unwrap_build(@graph.GraphBuilder::new(2))
  assert_eq(builder.add_edge(0, 0, 5L) is Ok(_), true)
  assert_eq(builder.add_edge(0, 1, 3L) is Ok(_), true)
  assert_eq(builder.add_edge(0, 1, 2L) is Ok(_), true)
  let g = builder.build()
  assert_eq(g.edge_count, 3)
  assert_eq(g.spec(1).to, 1)
  assert_eq(g.spec(2).to, 1)
  assert_eq(g.init_cap[1], 3L)
  assert_eq(g.init_cap[2], 2L)
}
