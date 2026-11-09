# BLUEPRINT — codel-mbt（CoDel 控制律 + 确定性离散事件网络 stub）

模块名：`huanguan-Q/codel`（无连字符）。单根包 + 独立证明包 `proofmodel/`。

## 文件清单与依赖序

| # | 文件 | 职责 | 依赖 |
|---|------|------|------|
| 1 | `codel.mbt` | CodelQueue：TARGET/INTERVAL 常数、control_law、dodequeue（first_above_time 状态机 + bytes 分支）、dequeue（dropping 状态机 + Linux count 传递）、enqueue（时间戳打标）；probe：control_law 单调性 | — |
| 2 | `netsim.mbt` | 确定性离散事件模拟器：事件队列（时间排序）、链路（每包 1000μs 发送耗时）、AIMD 发送器 stub（每 RTT 加性增、drop 即乘性减半）、local min sojourn 跟踪 | 1 |

## 测试文件

- `codel_wbtest.mbt`：T-CTRL-LAW / T-DODEQUEUE / T-DROP-SEQ / T-SERVIO / T-LINUX-COUNT（5+ 测试，全确定无随机）

## FORMAL（proofmodel/verify.mbtp）

- `control_law_monotone`：count 增大间隔不增——ceil(INTERVAL/√count) 含非线性 √，probe 一次，预计不可证 → 降级 RUNTIME（预登记）
- 可证替代：间隔 >= 0 的平凡界（LIA）作保底目标

## 判据映射（RFC → 测试）

| RFC | 测试 |
|---|---|
| §5.6 control_law | T-CTRL-LAW |
| §5.6 dodequeue | T-DODEQUEUE |
| §5.5 dequeue 状态机 | T-DROP-SEQ |
| §4.1-4.2 伺服系统设计目标 | T-SERVIO（min sojourn ≤ TARGET + 利用率） |
| §5.5 Linux count 变体 | T-LINUX-COUNT |

## 明确不实现

真实网络栈/TCP（stub 代替，本轮主题）；ECN 标记路径（RFC §7 可选扩展）；多队列/分类（§8）；数据中心变体（Appendix A）。
