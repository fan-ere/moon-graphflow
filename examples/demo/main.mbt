///|
fn main {
  println("moon-graphflow demo: network flow and graph matching algorithms")
  println("")
  // Scenario 1: assign workers to shifts with a maximum bipartite matching.
  let matching = match
    @matching.max_bipartite_matching(5, 5, [
      (0, 0),
      (0, 1),
      (1, 1),
      (1, 2),
      (2, 0),
      (3, 3),
      (4, 3),
      (4, 4),
    ]) {
    Ok(m) => m
    Err(e) => abort("\{e.message()}")
  }
  println("scenario 1: maximum bipartite matching, 5 workers to 5 shifts")
  for p in matching.pairs {
    println("  worker \{p.0} -> shift \{p.1}")
  }
  println("  matched \{matching.size} of 5 workers")
  println("")
  // Scenario 2: pump as much water as possible from spring 0 to basin 5 and
  // report the bottleneck the flow proves.
  let builder = match @graph.GraphBuilder::new(6) {
    Ok(b) => b
    Err(e) => abort("\{e.message()}")
  }
  let pipes = [
    (0, 1, 9L),
    (0, 2, 8L),
    (1, 3, 6L),
    (1, 4, 5L),
    (2, 3, 4L),
    (2, 4, 7L),
    (3, 5, 8L),
    (4, 5, 9L),
  ]
  for p in pipes {
    match builder.add_edge(p.0, p.1, p.2) {
      Ok(_) => ()
      Err(e) => abort("\{e.message()}")
    }
  }
  let g = builder.build()
  let solution = match @maxflow.solve_max_flow(g, 0, 5) {
    Ok(s) => s
    Err(e) => abort("\{e.message()}")
  }
  println("scenario 2: maximum flow from spring 0 to basin 5")
  println("  throughput: \{solution.total_flow}")
  println(
    "  bottleneck cut isolates \{solution.source_side.length()} node(s) on the spring side",
  )
  println("")
  // Scenario 3: minimum cost routing of the same network, then a weighted
  // assignment of 3 jobs to 4 machines.
  let builder2 = match @graph.GraphBuilder::new(4) {
    Ok(b) => b
    Err(e) => abort("\{e.message()}")
  }
  let shipments = [
    (0, 1, 4L, 2L),
    (0, 2, 3L, 5L),
    (1, 3, 3L, 3L),
    (2, 3, 4L, 1L),
  ]
  for p in shipments {
    match builder2.add_costed_edge(p.0, p.1, p.2, p.3) {
      Ok(_) => ()
      Err(e) => abort("\{e.message()}")
    }
  }
  let costed = builder2.build()
  let cheap = match @mincost.solve_min_cost_max_flow(costed, 0, 3) {
    Ok(s) => s
    Err(e) => abort("\{e.message()}")
  }
  println(
    "scenario 3: min cost flow of \{cheap.total_flow} units at cost \{cheap.total_cost}",
  )
  let weights = [6L, 2L, 8L, 3L, 9L, 4L, 1L, 5L, 7L, 3L, 2L, 9L]
  let assignment = match @matching.assign(3, 4, weights) {
    Ok(a) => a
    Err(e) => abort("\{e.message()}")
  }
  println("scenario 4: weighted job assignment, 3 jobs to 4 machines")
  for p in assignment.pairs {
    println("  job \{p.0} -> machine \{p.1}")
  }
  println("  total value \{assignment.total_weight}")
  println("")
  // Scenario 5: global min cut of a small reliability network.
  let builder3 = match @graph.GraphBuilder::new(5) {
    Ok(b) => b
    Err(e) => abort("\{e.message()}")
  }
  let links = [
    (0, 1, 3L),
    (0, 2, 2L),
    (1, 2, 2L),
    (1, 3, 4L),
    (2, 3, 5L),
    (3, 4, 6L),
  ]
  for p in links {
    match builder3.add_edge(p.0, p.1, p.2) {
      Ok(_) => ()
      Err(e) => abort("\{e.message()}")
    }
  }
  let mesh = builder3.build()
  let weakest = match @cut.global_min_cut(mesh) {
    Ok(c) => c
    Err(e) => abort("\{e.message()}")
  }
  println("scenario 5: global min cut of a 5 node mesh")
  println("  weakest separation costs \{weakest.cut_weight}")
  println("  one side: \{int_list(weakest.side_a)}")
  println("  other side: \{int_list(weakest.side_b)}")
}

///|
fn int_list(xs : Array[Int]) -> String {
  let mut out = "["
  for i, x in xs {
    if i > 0 {
      out = out + ", "
    }
    out = out + x.to_string()
  }
  out + "]"
}
