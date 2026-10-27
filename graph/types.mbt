///|
pub(all) struct EdgeSpec {
  from : Int
  to : Int
  capacity : Int64
  cost : Int64
}

///|
pub const NODE_LIMIT : Int = 100_000

///|
pub const EDGE_LIMIT : Int = 200_000

///|
pub const CAP_LIMIT : Int64 = 1_000_000_000L

///|
pub const COST_LIMIT : Int64 = 1_000_000_000L

///|
pub(all) enum BuildError {
  TooFewNodes(Int)
  TooManyNodes(Int)
  BadNode(Int, Int)
  BadCapacity(Int64)
  BadCost(Int64)
  TooManyEdges(Int)
}

///|
pub fn BuildError::message(self : BuildError) -> String {
  match self {
    TooFewNodes(n) => "node count must be at least 2, got \{n}"
    TooManyNodes(n) => "node count \{n} exceeds the limit \{NODE_LIMIT}"
    BadNode(node, total) => "node id \{node} out of range [0, \{total})"
    BadCapacity(c) => "edge capacity \{c} must be within [0, \{CAP_LIMIT}]"
    BadCost(c) =>
      "edge cost \{c} must be within [-\{COST_LIMIT}, \{COST_LIMIT}]"
    TooManyEdges(m) => "edge \{m} would exceed the edge limit \{EDGE_LIMIT}"
  }
}
