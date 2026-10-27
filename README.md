# moon-graphflow

[![CI](https://github.com/fan-ere/moon-graphflow/actions/workflows/ci.yml/badge.svg)](https://github.com/fan-ere/moon-graphflow/actions/workflows/ci.yml)

纯 MoonBit 实现的网络流与图匹配算法库：把「运输管道的最大吞吐」「任务指派的最低成本」「二分图的最大匹配」「全网最脆弱的割」这类问题，变成一次确定性的函数调用。

## 项目目标

Mooncakes 上已有不少图相关包：`Burnling-gx/moonpath`、`Deviaana/pathforge`、`hzc-666-ai/moonpathfinding` 提供网格上的 BFS / Dijkstra / A* 寻路，`FlyCloudC/mgraph` 提供无额外结构的图遍历。但整个生态（3337 个包的全量索引检索）没有任何一个包实现网络流：最大流、最小费用流、二分图匹配、最小割全部空缺。本项目补的是这一层：

- **最大流**：Dinic 算法，BFS 分层图上的迭代式阻塞流，同时给出 s-t 最小割的源侧顶点集与逐边流量。
- **最小费用流**：连续最短路 + 势函数 Dijkstra，虚拟超源 SPFA 初始化势函数以支持负费用边，并内置可达负环检测。
- **二分图匹配**：无权匹配（Kuhn 交错路，显式栈实现）与带权指派（Kuhn-Munkres，O(n³) 势函数增广），矩形矩阵直接支持。
- **全局最小割**：Stoer-Wagner 最大亲近度收缩，返回割值与两侧顶点划分。

## 与现有包的关系

逐包检索与对比记录见 [SOURCES.md](SOURCES.md)。结论：Mooncakes 3337 个包中没有任何包覆盖 Dinic / Ford-Fulkerson / push-relabel / 最小费用流 / Kuhn / Kuhn-Munkres / 指派问题 / Stoer-Wagner 中的任何一个；寻路包解决的是「单源最短路径」，流库解决的是「容量约束下的整体最优」，两者是不同族的问题。本项目不依赖任何第三方包，仅使用 `moonbitlang/core`。

## 特性一览

| 能力 | 说明 |
| --- | --- |
| 图构建 | `GraphBuilder` 有界校验（节点数 / 边数 / 容量 / 费用），自环与平行边合法 |
| 残量网络 | 每条边一对槽位（`k` 与 `k ^ 1`），反向边初始容量为 0、费用取负 |
| Dinic | BFS 分层 + 迭代式 DFS 阻塞流，全程无递归，不依赖调用栈深度 |
| 最小割证书 | 流结束后对残量网络再跑一次 BFS，源侧顶点集即最小割； crossing 容量恰等于流值 |
| 最小费用流 | 虚拟超源 SPFA 初始化势函数（支持负费用边），势函数 Dijkstra 连续最短路；SPFA 松弛计数超限判定负环 |
| 费用有界 | 逐边贡献 `流量 × 费用 ≤ 1e18`，累计超过 2e18 时返回 `CostOverflow` 而不是静默溢出 |
| Kuhn 匹配 | 显式栈交错路 + 时间戳去重，最大匹配一次求出 |
| Kuhn-Munkres | e-maxx 风格势函数增广，O(n³)，矩形矩阵以零权行补齐，语义为左部全匹配的最大权单射 |
| Stoer-Wagner | 稠密矩阵 O(n³) 收缩，平行边求和、自环忽略，返回割值与两侧划分 |
| 确定性 | 相同输入必得相同输出；算法内部比较全用下标序，无随机源、无时钟、无哈希序 |

## 安装前提

- MoonBit CLI：开发与验收使用 `moon 0.1.20260920`、`moonc v0.10.14`。
- 无第三方依赖，仅 `moonbitlang/core`。

## 快速上手

```sh
git clone https://github.com/fan-ere/moon-graphflow.git
cd moon-graphflow
moon run examples/demo --target wasm-gc
```

`examples/demo` 在四个后端输出一致的五段场景（native 在 Windows 控制台为 CRLF 行尾）：

```text
scenario 2: maximum flow from spring 0 to basin 5
  throughput: 17
  bottleneck cut isolates 1 node(s) on the spring side

scenario 3: min cost flow of 6 units at cost 33
```

库的使用方式（完整可运行版本见 `examples/demo/main.mbt`）：

```moonbit
let builder = @graph.GraphBuilder::new(6)
builder.add_edge(0, 1, 9L)
builder.add_edge(1, 3, 6L)
let g = builder.build()
let sol = @maxflow.solve_max_flow(g, 0, 5)
// sol.total_flow：最大流值
// sol.edge_flow[k]：第 k 条边的实际流量
// sol.source_side：最小割的源侧顶点（升序）
```

## 数值边界

所有量都有明确上限，超限在构建期或求解期返回显式错误，不会静默回绕：

| 量 | 上限 |
| --- | --- |
| 节点数（流 / 匹配） | 100,000 / 50,000 |
| 边数 | 200,000（流）/ 400,000（匹配） |
| 单边容量、单边费用绝对值 | 1,000,000,000 |
| 总流值 | ≤ 边数 × 单边容量，Int64 内恒不溢出 |
| 累计费用 | 2×10¹⁸，超出返回 `CostOverflow` |
| KM 矩阵边长 | 500（单边权 ≤ 1e12，非负） |
| 全局最小割节点数 | 600 |

## 验证

```sh
moon check --deny-warn --target all
moon build --target all
moon test --deny-warn --target all   # 42 个测试 × wasm / wasm-gc / js / native 全部通过
moon run examples/demo --target wasm-gc
```

测试策略分三层：

1. **已知实例**：教科书网络、星形、环、完全图 K5、菱形瓶颈等手工可验的期望值。
2. **对偶不变量**：每个流解都验证逐点流量守恒、源侧割容量等于流值、割上每条边饱和；每个割解都验证划分完整性与 crossing 权重。
3. **随机交叉验证**：Dinic 对 BFS 增广路参考实现跑 80 个随机实例；最小费用流对**全流量向量穷举**（混合进制枚举）跑 120 个随机实例；Kuhn 对边子集穷举跑 100 个实例；KM 对全排列穷举跑 120 个实例；Stoer-Wagner 对 2^n 子集穷举跑 100 个实例。所有随机源为固定种子 LCG，结果完全可复现。

## 边界（本库不做的事）

- 不处理负费用环：静态图含负环时最小费用流返回 `NegativeCycle`（负费用**边**只要不构成环即可）。
- 不做无向图最大流（有向图语义；无向需求请把每条边加成两个方向的平行边）。
- 不做一般图最大匹配（带花算法不在范围内）。
- 不做 IO 与持久化：输入是内存中的边表，输出是值与数组。
- KM 权重限定非负；带负权的全指派可给每个单元格加同一常数，不改变最优映射。

## 许可

MIT
