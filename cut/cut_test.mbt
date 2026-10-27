///|
fn unwrap_cut(
  r : Result[@cut.GlobalMinCut, @cut.CutError],
) -> @cut.GlobalMinCut {
  match r {
    Ok(c) => c
    Err(e) => abort("unexpected cut error: \{e.message()}")
  }
}

///|
fn build_cut_graph(
  n : Int,
  edges : Array[(Int, Int, Int64)],
) -> @graph.FlowGraph {
  let builder = match @graph.GraphBuilder::new(n) {
    Ok(b) => b
    Err(e) => abort("unexpected build error: \{e.message()}")
  }
  for e in edges {
    match builder.add_edge(e.0, e.1, e.2) {
      Ok(_) => ()
      Err(msg) => abort("unexpected build error: \{msg.message()}")
    }
  }
  builder.build()
}

///|
fn cut_error_message(r : Result[@cut.GlobalMinCut, @cut.CutError]) -> String {
  match r {
    Ok(_) => abort("expected a cut error")
    Err(e) => e.message()
  }
}

///|
fn brute_global_min_cut(n : Int, edges : Array[(Int, Int, Int64)]) -> Int64 {
  // Minimum over all nontrivial vertex subsets of the crossing weight.
  let mut best : Int64 = -1L
  let mut code = 1
  let limit = (1 << n) - 1
  while code < limit {
    let mut crossing : Int64 = 0L
    for e in edges {
      let a = (code >> e.0) & 1
      let b = (code >> e.1) & 1
      if a != b {
        crossing += e.2
      }
    }
    if best < 0L || crossing < best {
      best = crossing
    }
    code += 1
  }
  best
}

///|
fn check_sides(g : @graph.FlowGraph, cut : @cut.GlobalMinCut) -> Unit raise {
  let in_a : Array[Bool] = Array::make(g.node_count, false)
  for x in cut.side_a {
    in_a[x] = true
  }
  // Both sides partition every node exactly once.
  assert_eq(cut.side_a.length() + cut.side_b.length(), g.node_count)
  for x in cut.side_b {
    assert_eq(in_a[x], false)
  }
  // The crossing weight of the reported partition equals the reported value.
  let mut crossing : Int64 = 0L
  for k in 0..<g.edge_count {
    let spec = g.spec(k)
    if spec.from != spec.to {
      if in_a[spec.from] != in_a[spec.to] {
        crossing += spec.capacity
      }
    }
  }
  assert_eq(crossing, cut.cut_weight)
}

///|
test "cycle graph has global min cut two" {
  // A 5-cycle of unit edges: isolating any node cuts 2 edges.
  let g = build_cut_graph(5, [
    (0, 1, 1L),
    (1, 2, 1L),
    (2, 3, 1L),
    (3, 4, 1L),
    (4, 0, 1L),
  ])
  let cut = unwrap_cut(@cut.global_min_cut(g))
  assert_eq(cut.cut_weight, 2L)
  check_sides(g, cut)
}

///|
test "star graph isolates a leaf" {
  let g = build_cut_graph(4, [(0, 1, 5L), (0, 2, 7L), (0, 3, 9L)])
  let cut = unwrap_cut(@cut.global_min_cut(g))
  assert_eq(cut.cut_weight, 5L)
  check_sides(g, cut)
}

///|
test "disconnected graph has zero cut" {
  let g = build_cut_graph(4, [(0, 1, 3L), (2, 3, 4L)])
  let cut = unwrap_cut(@cut.global_min_cut(g))
  assert_eq(cut.cut_weight, 0L)
  check_sides(g, cut)
}

///|
test "complete graph k5 has cut four" {
  let builder = match @graph.GraphBuilder::new(5) {
    Ok(b) => b
    Err(e) => abort("unexpected build error: \{e.message()}")
  }
  for u in 0..<5 {
    for v in 0..<5 {
      if u < v {
        match builder.add_edge(u, v, 1L) {
          Ok(_) => ()
          Err(msg) => abort("unexpected build error: \{msg.message()}")
        }
      }
    }
  }
  let g = builder.build()
  let cut = unwrap_cut(@cut.global_min_cut(g))
  assert_eq(cut.cut_weight, 4L)
  check_sides(g, cut)
}

///|
test "cut error message for oversized graphs" {
  // Build a graph with more nodes than the cut limit using two-node additions
  // only: exceeding the limit is checked before any scan work happens.
  let big = @cut.CUT_NODE_LIMIT + 1
  let g = build_cut_graph(2, [])
  let _ = g
  // Constructing a real oversized FlowGraph is unnecessary: call the check
  // path through a synthetic graph record built by the builder.
  let builder = match @graph.GraphBuilder::new(big) {
    Ok(b) => b
    Err(e) => abort("unexpected build error: \{e.message()}")
  }
  let g2 = builder.build()
  assert_eq(
    cut_error_message(@cut.global_min_cut(g2)),
    "global min cut supports at most \{@cut.CUT_NODE_LIMIT} nodes, got \{big}",
  )
}

///|
test "parallel edges and zero capacities behave deterministically" {
  let g = build_cut_graph(3, [(0, 1, 2L), (0, 1, 2L), (1, 2, 0L)])
  let cut = unwrap_cut(@cut.global_min_cut(g))
  assert_eq(cut.cut_weight, 0L)
  check_sides(g, cut)
}

///|
test "randomized cross-check against subset enumeration on 100 instances" {
  let mut seed : Int64 = 777000999111333L
  for _iter in 0..<100 {
    seed = seed * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
    let n = 3 + (seed & 0x3L).to_int()
    seed = seed * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
    let m = 1 + (seed & 0x7L).to_int()
    let edges : Array[(Int, Int, Int64)] = []
    let builder = match @graph.GraphBuilder::new(n) {
      Ok(b) => b
      Err(e) => abort("unexpected build error: \{e.message()}")
    }
    for _k in 0..<m {
      seed = seed * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
      let u = (seed & 0x7L).to_int() % n
      seed = seed * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
      let v = (seed & 0x7L).to_int() % n
      seed = seed * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
      let c = 1 + ((seed >> 4) & 0xFL).to_int()
      if u != v {
        match builder.add_edge(u, v, c.to_int64()) {
          Ok(_) => ()
          Err(msg) => abort("unexpected build error: \{msg.message()}")
        }
        edges.push((u, v, c.to_int64()))
      }
    }
    let g = builder.build()
    let cut = unwrap_cut(@cut.global_min_cut(g))
    assert_eq(cut.cut_weight, brute_global_min_cut(n, edges))
    check_sides(g, cut)
  }
}
