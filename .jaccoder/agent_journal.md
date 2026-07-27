## Issues
- [turn 12] Graph "0 functions" after ingest: server restarts from HMR between ingest and get_graph, clearing the graph. Added retry logic - if first get_graph returns empty, retry once.
- [turn 12] Function name input disappeared after first keystroke: conditional `{if not target_fn and ingest_result}` hid the input as soon as target_fn became non-empty. Changed to always show after ingest with `{if ingest_result}`.

## Learnings
- Server restarts from HMR clear the in-memory graph. get_graph after ingest may return empty on first call. Retry once.
- Conditional rendering that depends on the same state a controlled input writes to will hide the input on first keystroke.

## Last Action
Turn 12: Fixed two blocking bugs.
- Graph empty after ingest: added retry logic for get_graph when first response has 0 nodes
- Function input not editable: changed from conditional fallback to always-visible "Target Function" card after ingest
- Verified: input accepts typed text, ContextPanel shows real callers/callees
