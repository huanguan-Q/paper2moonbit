# BLUEPRINT — Lifeguard (arXiv:1707.00788) → MoonBit

论文：《Lifeguard: Local Health Awareness for More Accurate Failure Detection》
Dadgar, Phillips, Currey（HashiCorp），DSN-W 2018，arXiv:1707.00788v2。
目标：SWIM 成员协议 + Lifeguard 三扩展（LHA-Probe / LHA-Suspicion / Buddy System）的核心算法。

## 论文判据（规格测试来源）

1. **LHM 饱和计数器**（0..S，S=8）：
   - 成功探测 ack → −1；探测失败 → +1；反驳自身 suspect → +1；missed nack → +1
   - 不越界（饱和于 0 与 8）
2. **退避**：ProbeInterval = Base·(LHM+1)，ProbeTimeout = Base·(LHM+1)
   （Base = 1s / 500ms；实现用可注入参数）
3. **怀疑超时**：SuspicionTimeout = max(Min, Max − (Max−Min)·log(C+1)/log(K+1))，K=3
   Min = α·log10(n)·ProbeInterval，Max = β·Min（α=5, β=6 论文推荐组合）
4. **SWIM 基座**：ping → 超时 → ping-req（k 个成员间接探测）→ suspect
   → 反驳（被怀疑者 incarnation+1 发 alive；alive 需更高 incarnation 才覆盖 suspect）
   → 超时未反驳 → confirm（不可逆）
5. **nack**：ping-req 接收者在探测超时 80% 时刻未收到 ack → 回 nack；
   nack + ack 均视为间接探测成功。

## 依赖序

1. `swim.mbt` — 纯状态机：成员表、消息类型、awareness、超时公式、消息处理（无 IO）
2. `driver.mbt` — async 仿真：moonbitlang/async 任务组驱动多节点 + 虚拟消息总线
   （投递延迟模拟网络），端到端故障检测场景
3. 测试：黑盒（论文判据 1/3/4 已知值断言）+ async 集成测试（故障检测收敛、健康节点零误报）

## 范围边界（不做）

- 真实 UDP/TCP socket（用虚拟总线代替——论文算法贡献在协议逻辑，不在传输）
- gossip 捎带的 λlog(n) 重传计数（用简化全量广播记录偏差）
- 优雅离开（left 消息）

## 偏差记录

- Buddy System：ping 中捎带针对目标的 suspect 通知 → 简化为 suspect 消息即时全量广播
- 消息重传：每条更新固定广播一次（非 λlog(n) 次）
- 时间参数单位毫秒，仿真用加速时钟（Base=20ms/10ms 级别）
