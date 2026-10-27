///|
fn unwrap_match(
  r : Result[@matching.Matching, @matching.MatchError],
) -> @matching.Matching {
  match r {
    Ok(m) => m
    Err(e) => abort("unexpected matching error: \{e.message()}")
  }
}

///|
fn match_error_message(
  r : Result[@matching.Matching, @matching.MatchError],
) -> String {
  match r {
    Ok(_) => abort("expected a matching error")
    Err(e) => e.message()
  }
}

///|
fn brute_max_matching(
  left : Int,
  right : Int,
  edges : Array[(Int, Int)],
) -> Int {
  // Try every subset of edges on tiny instances and keep the largest valid
  // matching, where no node appears twice.
  let m = edges.length()
  let used_left : Array[Bool] = Array::make(left, false)
  let used_right : Array[Bool] = Array::make(right, false)
  let mut best = 0
  let mut code = 0
  let limit = 1 << m
  while code < limit {
    for i in 0..<left {
      used_left[i] = false
    }
    for j in 0..<right {
      used_right[j] = false
    }
    let mut size = 0
    let mut ok = true
    let mut k = 0
    while ok && k < m {
      if ((code >> k) & 1) == 1 {
        let e = edges[k]
        if used_left[e.0] || used_right[e.1] {
          ok = false
        } else {
          used_left[e.0] = true
          used_right[e.1] = true
          size += 1
        }
      }
      k += 1
    }
    if ok && size > best {
      best = size
    }
    code += 1
  }
  best
}

///|
test "kuhn finds the perfect matching of a square instance" {
  let m = unwrap_match(
    @matching.max_bipartite_matching(3, 3, [(0, 1), (1, 0), (1, 2), (2, 0)]),
  )
  assert_eq(m.size, 3)
  assert_eq(m.pairs.length(), 3)
  // Every left and right index appears exactly once.
  let seen_left : Array[Bool] = Array::make(3, false)
  let seen_right : Array[Bool] = Array::make(3, false)
  for p in m.pairs {
    assert_eq(seen_left[p.0], false)
    assert_eq(seen_right[p.1], false)
    seen_left[p.0] = true
    seen_right[p.1] = true
  }
}

///|
test "kuhn handles empty adjacency and duplicates" {
  let m = unwrap_match(@matching.max_bipartite_matching(2, 2, []))
  assert_eq(m.size, 0)
  assert_eq(m.pairs, [])
  let m2 = unwrap_match(
    @matching.max_bipartite_matching(2, 2, [(0, 0), (0, 0), (1, 1)]),
  )
  assert_eq(m2.size, 2)
}

///|
test "kuhn matches through alternating paths" {
  // 0-v0, 1-v0, 1-v1, 2-v1: the augmenting path for 2 reroutes 0 and 1.
  let m = unwrap_match(
    @matching.max_bipartite_matching(3, 2, [(0, 0), (1, 0), (1, 1), (2, 1)]),
  )
  assert_eq(m.size, 2)
}

///|
test "kuhn error messages" {
  assert_eq(
    match_error_message(@matching.max_bipartite_matching(0, 2, [])),
    "left side size must be at least 1, got 0",
  )
  assert_eq(
    match_error_message(@matching.max_bipartite_matching(2, 0, [])),
    "right side size must be at least 1, got 0",
  )
  assert_eq(
    match_error_message(@matching.max_bipartite_matching(2, 2, [(0, 2)])),
    "edge (0, 2) out of range [0, 2) x [0, 2)",
  )
  assert_eq(
    match_error_message(
      @matching.max_bipartite_matching(@matching.MATCH_SIDE_LIMIT + 1, 2, []),
    ),
    "side size \{@matching.MATCH_SIDE_LIMIT + 1} exceeds the matching side limit",
  )
}

///|
test "randomized kuhn cross-check against subset enumeration on 100 instances" {
  let mut seed : Int64 = 987654321000000123L
  for _iter in 0..<100 {
    seed = seed * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
    let left = 1 + (seed & 0x7L).to_int()
    seed = seed * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
    let right = 1 + (seed & 0x7L).to_int()
    seed = seed * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
    let m = (seed & 0x7L).to_int()
    let edges : Array[(Int, Int)] = []
    for _k in 0..<m {
      seed = seed * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
      let u = (seed & 0x3L).to_int() % left
      seed = seed * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
      let v = (seed & 0x3L).to_int() % right
      edges.push((u, v))
    }
    let result = unwrap_match(
      @matching.max_bipartite_matching(left, right, edges),
    )
    assert_eq(result.size, brute_max_matching(left, right, edges))
    // Reported pairs are valid and consistent with the reported size.
    let seen_left : Array[Bool] = Array::make(left, false)
    let seen_right : Array[Bool] = Array::make(right, false)
    for p in result.pairs {
      assert_eq(seen_left[p.0], false)
      assert_eq(seen_right[p.1], false)
      seen_left[p.0] = true
      seen_right[p.1] = true
    }
    assert_eq(result.pairs.length(), result.size)
  }
}

///|
fn brute_best_assignment(weights : Array[Int64], n : Int) -> Int64 {
  // Maximum weight over all permutations of a square matrix.
  let order : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    order[i] = i
  }
  let mut best : Int64 = -1L
  let mut more = true
  while more {
    more = false
    let mut total : Int64 = 0L
    for i in 0..<n {
      total += weights[i * n + order[i]]
    }
    if best < 0L || total > best {
      best = total
    }
    // Next permutation (lexicographic).
    let mut i = n - 2
    while i >= 0 && order[i] >= order[i + 1] {
      i -= 1
    }
    if i >= 0 {
      let mut j = n - 1
      while order[j] <= order[i] {
        j -= 1
      }
      let tmp = order[i]
      order[i] = order[j]
      order[j] = tmp
      let mut lo = i + 1
      let mut hi = n - 1
      while lo < hi {
        let t2 = order[lo]
        order[lo] = order[hi]
        order[hi] = t2
        lo += 1
        hi -= 1
      }
      more = true
    }
  }
  best
}

///|
test "km solves the square assignment exactly on 120 random instances" {
  let mut seed : Int64 = 555000111222333L
  for _iter in 0..<120 {
    let n = 2 + ((seed >> 8) & 0x3L).to_int()
    let weights : Array[Int64] = []
    for _k in 0..<(n * n) {
      seed = seed * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
      weights.push((seed >> 10) & 0xFFL)
    }
    let result = unwrap_mc_assign(@matching.assign(n, n, weights))
    assert_eq(result.pairs.length(), n)
    assert_eq(result.total_weight, brute_best_assignment(weights, n))
    // Injectivity of the reported pairs.
    let used : Array[Bool] = Array::make(n, false)
    for p in result.pairs {
      assert_eq(used[p.1], false)
      used[p.1] = true
    }
  }
}

///|
fn unwrap_mc_assign(
  r : Result[@matching.Assignment, @matching.MatchError],
) -> @matching.Assignment {
  match r {
    Ok(a) => a
    Err(e) => abort("unexpected assignment error: \{e.message()}")
  }
}

///|
test "km rectangular assignment uses the cheaper columns well" {
  // 2 rows, 3 columns; row 0 prefers column 0, row 1 prefers column 1.
  let weights = [9L, 1L, 1L, 1L, 9L, 1L]
  let a = unwrap_mc_assign(@matching.assign(2, 3, weights))
  assert_eq(a.total_weight, 18L)
  assert_eq(a.pairs.length(), 2)
}

///|
fn assign_error_message(
  r : Result[@matching.Assignment, @matching.MatchError],
) -> String {
  match r {
    Ok(_) => abort("expected an assignment error")
    Err(e) => e.message()
  }
}

///|
test "km error messages" {
  assert_eq(
    assign_error_message(@matching.assign(3, 2, [1L, 1L, 1L, 1L, 1L, 1L])),
    "right side 2 is smaller than left side 3",
  )
  assert_eq(
    assign_error_message(@matching.assign(2, 2, [1L, 1L, 1L])),
    "weight matrix holds 3 entries but 4 are required",
  )
  assert_eq(
    assign_error_message(@matching.assign(2, 2, [1L, 1L, -2L, 1L])),
    "assignment weights must be within [0, \{@matching.KM_WEIGHT_LIMIT}], got -2",
  )
}
