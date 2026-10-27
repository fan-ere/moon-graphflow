# SOURCES — 选题查重与生态对比记录

本文记录 moon-graphflow 选题时的检索范围、关键词与逐包对比，用于证明「MoonBit 生态中网络流与图匹配能力空缺」这一判断可复核。

## 检索范围与方法

- 数据源：Mooncakes 官方模块索引全量快照（`mooncakes-index-20261026.json`，3337 个包，抓取于 2026-10-26，本地存档于竞赛材料目录）。
- 方法：对包名、描述（前 160 字符）与关键词做小写子串匹配，两轮共 120+ 个关键词。
- 补充：对疑似相邻的包逐个阅读其索引描述与仓库 README 定位能力边界。

## 核心查重关键词（全部 0 命中）

`dinic`、`ford-fulkerson`、`fulkerson`、`push-relabel`、`push relabel`、`mcmf`、`min-cost`、`min cost`、`max flow`、`maximum flow`、`network flow`、`maxflow`、`mincut`、`max-flow`、`min-cut`、`stoer`、`global min`、`kuhn`、`munkres`、`assignment problem`、`transportation problem`、`bipartite`、`hungarian`、`pubgrub`（顺带验证）

## 相邻包与能力边界

| 包 | 能力 | 与本项目的关系 |
| --- | --- | --- |
| `Burnling-gx/moonpath`、`Deviaana/pathforge`、`hzc-666-ai/moonpathfinding`、`Feather119/moon_path`、`Suquster/moonbit-pathfinding`、`wzx2007/moonpath` | 网格 / 图上的 BFS、Dijkstra、A* 单源寻路 | 不同族问题：寻路回答「从 s 到 t 的最短路」，本项目回答「容量约束下 s→t 的整体最大吞吐与最低费用」。路径算法不涉及残量网络、阻塞流、势函数与匹配增广 |
| `FlyCloudC/mgraph` | 不复制图结构的遍历 | 只覆盖遍历，无流、匹配、割 |
| `bobzhang/flowgraph`、`AlexenderSokolov/moonflowgraph` | 有向图构建并导出 Graphviz DOT / Mermaid | 可视化导出工具，无算法 |
| `bobzhang/differential` |微分数据流移植 | 增量计算运行时，与网络流无关 |
| `chenliyi-cly/moonfat` | FAT12/16/32 卷格式 | 无关（选题调研时的其他候选方向） |
| `Lfan-ke/moonapi`、`moonbitstack/moonapi` | FastAPI 风格 Web 框架 | 关键词 "fastapi" 的误命中，无关 |
| `trkbt10/vcdb`、`ywz1314/vector` | 向量检索 / HNSW | ANN 索引，无网络流 |
| `FlyCloudC/GJK` | GJK 碰撞检测 | 计算几何，与图流无关 |
| `weopqrst/moonphys`、`mizchi/physics` | 2D 物理引擎 | 无关 |
| `jhshuai/moonlarder` | LRU/LFU/ARC/W-TinyLFU 缓存 | 缓存淘汰策略，无流算法 |
| `brother-666/moonwheelkit` | 层级时间轮 | 调度数据结构，无流算法 |
| `binhongcha/moonsuccinct` | 紧凑索引原语 | 无 FM-index 冲突，且与本项目无关 |

## 检索时间线

- 2026-10-27：基于 2026-10-26 全量索引完成两轮关键词扫描与相邻包定位，确认空缺后定题 `moon-graphflow`。
- 本项目实现前未参考任何上游流库源码；算法依据为公开教科书内容（CLRS 网络流章节、e-maxx 与 cp-algorithms 的 Dinic / MCMF / Kuhn / KM / Stoer-Wagner 通用表述），全部代码独立编写。

## 验收口径

- 测试：42 个测试，`moon test --deny-warn --target all` 在 wasm / wasm-gc / js / native 四目标全部通过（本地工具链 moon 0.1.20260920 / moonc v0.10.14）。
- 示例：`moon run examples/demo` 三后端（wasm-gc / js / native）输出逐字一致（native 在 Windows 为 CRLF 行尾）。
