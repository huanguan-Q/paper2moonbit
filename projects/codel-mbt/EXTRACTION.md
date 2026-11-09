# S1 算法抽取清单 — CoDel (Nichols, Jacobson et al., RFC 8289)

> 规范：Controlled Delay Active Queue Management（IETF RFC 8289，含 §5 完整伪代码）
> 定性：真实系统工程论文（AQM 队列管理）。**降级路线本轮主题**：网络/发送器/时钟
> 全部为确定性离散事件 stub，CoDel 控制律全量实现——与 RQGM 的 LLM stub 模式同构，
> 直接检验"系统工程类论文可降级实现"声明。

## 可转核心（RFC §5.4-5.7 伪代码逐行翻译）

| # | 组件 | 规范出处 | 规格 |
|---|------|---------|------|
| C1 | 常数：TARGET = 5ms, INTERVAL = 100ms（MS2TIME 整数 μs 域）；time_t 整数 | §5.4 + §5.7 | |
| C2 | control_law：drop_next = t + INTERVAL/sqrt(count)（TCP 吞吐 √p 依赖的伺服律） | §5.6 | |
| C3 | dodequeue：sojourn = now − tstamp；sojourn < TARGET 或 bytes ≤ maxpacket → first_above_time=0；否则 above 起记 first_above_time=now+INTERVAL，到时 ok_to_drop | §5.6 helper | 双 AQM 分支（时延 + 积压） |
| C4 | dequeue 状态机：dropping 时 while(now≥drop_next) 逐包丢 + count++ + 重调度；非 dropping 且 ok_to_drop → 进入 dropping，Linux 变体 count 传递（delta>1 且 now−drop_next<16·INTERVAL → count=delta） | §5.5 | |
| C5 | 空队列复位：dequeue 空时 first_above_time=0 | §5.6 | |

## 测试判据

1. **T-CTRL-LAW**（精确）：control_law(t,1)=t+100ms；count=4→+50ms；count=100→+10ms（√p 伺服律数值）
2. **T-DODEQUEUE**（状态机）：below TARGET 复位；above 持续 INTERVAL 才 ok_to_drop；空队列复位
3. **T-DROP-SEQ**（状态机 drop 序列）：持续拥塞流下 drop 间隔序列 = INTERVAL/√1,/√2,/√3…（control_law 序列逐步匹配）；below 后退出 dropping
4. **T-SERVIO**（端到端伺服判据，论文核心声明）：类 TCP AIMD 发送器 stub（每 RTT 加性增、drop 即乘性减）驱动下：稳态 local min sojourn ≤ TARGET（"good queue"）且链路利用率 ≥ 0.5（高吞吐不空转）
5. **T-LINUX-COUNT**：退出后快速回升（now−drop_next < 16·INTERVAL 且 delta>1）时 count 继承（重入省收敛）

## 偏差声明（预登记）

- 网络/发送器/时钟全部确定性离散事件 stub（AIMD 发送器为 TCP 的行为近似，非 TCP 实现）——本轮主题即验证此降级路线
- RFC 双 AQM 的 bytes 分支按包计数近似（maxpacket=1500，固定包长 1500B）
- time_t 用 Int μs（RFC 允许整数 μs+）；control_law 的 INTERVAL/√count 在整数域 ceil 化（Linux 实现同款整数化）
- 原始 ACM Queue 2012 论文以 RFC 8289 为规范源（RFC 由原作者撰写并含更精确伪代码，登记映射）

## FORMAL 候选

- control_law 单调性：count 增大 → 间隔不增（Integer/ceil 域——√ 为非线性，预计不可证，probe 一次）
- 预登记降级：状态机序列需队列数组 → RUNTIME
