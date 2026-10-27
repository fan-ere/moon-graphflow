///|
pub(all) enum MatchError {
  BadLeftSize(Int)
  BadRightSize(Int)
  TooLargeSide(Int)
  RightSmallerThanLeft(Int, Int)
  BadEdge(Int, Int, Int, Int)
  TooManyEdges(Int)
  BadWeight(Int64)
  WeightCountMismatch(Int, Int)
}

///|
pub fn MatchError::message(self : MatchError) -> String {
  match self {
    BadLeftSize(n) => "left side size must be at least 1, got \{n}"
    BadRightSize(n) => "right side size must be at least 1, got \{n}"
    TooLargeSide(n) => "side size \{n} exceeds the matching side limit"
    RightSmallerThanLeft(l, r) =>
      "right side \{r} is smaller than left side \{l}"
    BadEdge(u, v, left, right) =>
      "edge (\{u}, \{v}) out of range [0, \{left}) x [0, \{right})"
    TooManyEdges(m) => "edge \{m} would exceed the matching edge limit"
    BadWeight(w) =>
      "assignment weights must be within [0, \{KM_WEIGHT_LIMIT}], got \{w}"
    WeightCountMismatch(got, want) =>
      "weight matrix holds \{got} entries but \{want} are required"
  }
}

///|
pub struct Matching {
  pairs : Array[(Int, Int)]
  size : Int
}

///|
pub struct Assignment {
  pairs : Array[(Int, Int)]
  total_weight : Int64
}

///|
pub const MATCH_SIDE_LIMIT : Int = 50_000

///|
pub const MATCH_EDGE_LIMIT : Int = 400_000

///|
pub const KM_SIDE_LIMIT : Int = 500

///|
pub const KM_WEIGHT_LIMIT : Int64 = 1_000_000_000_000L

///|
pub fn max_bipartite_matching(
  left : Int,
  right : Int,
  edges : Array[(Int, Int)],
) -> Result[Matching, MatchError] {
  if left < 1 {
    return Err(BadLeftSize(left))
  }
  if right < 1 {
    return Err(BadRightSize(right))
  }
  if left > MATCH_SIDE_LIMIT || right > MATCH_SIDE_LIMIT {
    return Err(TooLargeSide(if left > MATCH_SIDE_LIMIT { left } else { right }))
  }
  if edges.length() > MATCH_EDGE_LIMIT {
    return Err(TooManyEdges(edges.length()))
  }
  let adj : Array[Array[Int]] = Array::make(left, [])
  for i in 0..<left {
    adj[i] = []
  }
  for pair in edges {
    let u = pair.0
    let v = pair.1
    if u < 0 || u >= left || v < 0 || v >= right {
      return Err(BadEdge(u, v, left, right))
    }
    adj[u].push(v)
  }
  let match_left : Array[Int] = Array::make(left, -1)
  let match_right : Array[Int] = Array::make(right, -1)
  let seen : Array[Int] = Array::make(right, -1)
  // Iterative Kuhn: an explicit stack replaces the usual recursion, so the
  // function never depends on the call stack depth of the host platform.
  let stack_vertex : Array[Int] = Array::make(left + 1, 0)
  let stack_index : Array[Int] = Array::make(left + 1, 0)
  let chosen : Array[Int] = Array::make(left + 1, 0)
  let mut total = 0
  for u in 0..<left {
    if match_left[u] != -1 {
      continue
    }
    let mut depth = 1
    stack_vertex[0] = u
    stack_index[0] = 0
    let mut found = false
    while depth > 0 && !found {
      let v = stack_vertex[depth - 1]
      let idx = stack_index[depth - 1]
      if idx >= adj[v].length() {
        depth -= 1
        continue
      }
      stack_index[depth - 1] = idx + 1
      let w = adj[v][idx]
      if seen[w] == u {
        continue
      }
      seen[w] = u
      if match_right[w] == -1 {
        // Augment: retrace the alternating path from the top back to u.
        match_right[w] = v
        match_left[v] = w
        let mut level = depth - 1
        while level > 0 {
          let wk = chosen[level - 1]
          let vk = stack_vertex[level - 1]
          match_right[wk] = vk
          match_left[vk] = wk
          level -= 1
        }
        found = true
      } else {
        chosen[depth - 1] = w
        stack_vertex[depth] = match_right[w]
        stack_index[depth] = 0
        depth += 1
      }
    }
    if found {
      total += 1
    }
  }
  let pairs : Array[(Int, Int)] = []
  for u in 0..<left {
    if match_left[u] != -1 {
      pairs.push((u, match_left[u]))
    }
  }
  Ok({ pairs, size: total, })
}

///|
pub fn assign(
  left : Int,
  right : Int,
  weights : Array[Int64],
) -> Result[Assignment, MatchError] {
  if left < 1 {
    return Err(BadLeftSize(left))
  }
  if right < 1 {
    return Err(BadRightSize(right))
  }
  if right < left {
    return Err(RightSmallerThanLeft(left, right))
  }
  if left > KM_SIDE_LIMIT || right > KM_SIDE_LIMIT {
    return Err(TooLargeSide(if left > KM_SIDE_LIMIT { left } else { right }))
  }
  if weights.length() != left * right {
    return Err(WeightCountMismatch(weights.length(), left * right))
  }
  for w in weights {
    if w < 0L || w > KM_WEIGHT_LIMIT {
      return Err(BadWeight(w))
    }
  }
  // Jonker-style e-maxx Kuhn-Munkres on the padded square of size `right`.
  // Padded rows carry weight zero, so minimizing their cost -w never changes
  // the optimum for the real rows and every real row ends up matched to a
  // distinct real column.
  let n = right
  let u : Array[Int64] = Array::make(n + 1, 0L)
  let v : Array[Int64] = Array::make(n + 1, 0L)
  let p : Array[Int] = Array::make(n + 1, 0)
  let way : Array[Int] = Array::make(n + 1, 0)
  let minv : Array[Int64] = Array::make(n + 1, 0L)
  let used : Array[Bool] = Array::make(n + 1, false)
  let weight_at = fn(i : Int, j : Int) -> Int64 {
    if i < left {
      -weights[i * right + j]
    } else {
      0L
    }
  }
  for i in 1..<=n {
    p[0] = i
    let mut j0 = 0
    for j in 0..<=n {
      minv[j] = 9_223_372_036_854_775_807L / 4L
      used[j] = false
    }
    while true {
      used[j0] = true
      let i0 = p[j0]
      let mut delta = 9_223_372_036_854_775_807L / 4L
      let mut j1 = 0
      for j in 1..<=n {
        if !used[j] {
          let cur = weight_at(i0 - 1, j - 1) - u[i0] - v[j]
          if cur < minv[j] {
            minv[j] = cur
            way[j] = j0
          }
          if minv[j] < delta {
            delta = minv[j]
            j1 = j
          }
        }
      }
      for j in 0..<=n {
        if used[j] {
          u[p[j]] += delta
          v[j] -= delta
        } else {
          minv[j] -= delta
        }
      }
      j0 = j1
      if p[j0] == 0 {
        break
      }
    }
    while true {
      let j1 = way[j0]
      p[j0] = p[j1]
      j0 = j1
      if j0 == 0 {
        break
      }
    }
  }
  // Invert the column -> row mapping, then collect the real pairs.
  let row_col : Array[Int] = Array::make(n + 1, 0)
  for j in 1..<=n {
    row_col[p[j]] = j
  }
  let pairs : Array[(Int, Int)] = []
  let mut total : Int64 = 0L
  for i in 0..<left {
    let col = row_col[i + 1]
    pairs.push((i, col - 1))
    total += weights[i * right + col - 1]
  }
  Ok({ pairs, total_weight: total, })
}
