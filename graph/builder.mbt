///|
pub struct GraphBuilder {
  node_count : Int
  edges : Array[EdgeSpec]
}

///|
pub fn GraphBuilder::new(node_count : Int) -> Result[GraphBuilder, BuildError] {
  if node_count < 2 {
    Err(TooFewNodes(node_count))
  } else if node_count > NODE_LIMIT {
    Err(TooManyNodes(node_count))
  } else {
    Ok({ node_count, edges: [], })
  }
}

///|
pub fn GraphBuilder::add_edge(
  self : GraphBuilder,
  u : Int,
  v : Int,
  capacity : Int64,
) -> Result[Unit, BuildError] {
  self.add_costed_edge(u, v, capacity, 0L)
}

///|
pub fn GraphBuilder::add_costed_edge(
  self : GraphBuilder,
  u : Int,
  v : Int,
  capacity : Int64,
  cost : Int64,
) -> Result[Unit, BuildError] {
  if u < 0 || u >= self.node_count {
    return Err(BadNode(u, self.node_count))
  }
  if v < 0 || v >= self.node_count {
    return Err(BadNode(v, self.node_count))
  }
  if capacity < 0L || capacity > CAP_LIMIT {
    return Err(BadCapacity(capacity))
  }
  if cost > COST_LIMIT || cost < -COST_LIMIT {
    return Err(BadCost(cost))
  }
  if self.edges.length() >= EDGE_LIMIT {
    return Err(TooManyEdges(self.edges.length()))
  }
  self.edges.push({ from: u, to: v, capacity, cost, })
  Ok(())
}

///|
pub fn GraphBuilder::edge_count(self : GraphBuilder) -> Int {
  self.edges.length()
}

///|
pub struct FlowGraph {
  node_count : Int
  edge_count : Int
  slot_count : Int
  to : Array[Int]
  cap : Array[Int64]
  cost : Array[Int64]
  first : Array[Int]
  next_edge : Array[Int]
  init_cap : Array[Int64]
}

///|
pub fn GraphBuilder::build(self : GraphBuilder) -> FlowGraph {
  let m = self.edges.length()
  let to : Array[Int] = []
  let cap : Array[Int64] = []
  let cost : Array[Int64] = []
  let next_edge : Array[Int] = []
  let init_cap : Array[Int64] = []
  let first : Array[Int] = Array::make(self.node_count, -1)
  for k, spec in self.edges {
    to.push(spec.to)
    cap.push(spec.capacity)
    cost.push(spec.cost)
    next_edge.push(first[spec.from])
    first[spec.from] = k * 2
    to.push(spec.from)
    cap.push(0L)
    cost.push(-spec.cost)
    next_edge.push(first[spec.to])
    first[spec.to] = k * 2 + 1
    init_cap.push(spec.capacity)
  }
  {
    node_count: self.node_count,
    edge_count: m,
    slot_count: m * 2,
    to,
    cap,
    cost,
    first,
    next_edge,
    init_cap,
  }
}

///|
pub fn FlowGraph::spec(self : FlowGraph, k : Int) -> EdgeSpec {
  {
    from: self.to[k * 2 + 1],
    to: self.to[k * 2],
    capacity: self.init_cap[k],
    cost: self.cost[k * 2],
  }
}
