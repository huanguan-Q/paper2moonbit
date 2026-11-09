# codel-mbt

CoDel (Controlled Delay) active queue management — the control law of
IETF RFC 8289 (Nichols, Jacobson et al.) implemented in MoonBit, driven by
the RFC's normative pseudocode and test vectors over a deterministic
discrete-event network stub (AIMD sender + bottleneck link).

- `control_law(t, count)` — the sqrt(p) servo schedule (RFC §5.6)
- `CodelQueue::enqueue/dequeue/dodequeue` — §5.4-5.6 state machine verbatim
- Servo judgment: steady-state local-min sojourn ≤ 5 ms TARGET with high
  link utilization (deterministic simulation, no randomness)

```bash
moon test
```

## Provenance & License

- **Algorithm**: specified in IETF RFC 8289, an IETF open standard whose
  copyright terms permit implementation. Pseudocode and constants are cited
  from the RFC; this is an independent MoonBit implementation.
- **Code**: original MoonBit implementation, Apache-2.0.
