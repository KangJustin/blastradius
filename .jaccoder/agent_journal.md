## Issues
- [turn 8] Call Graph showed "0 functions, 0 calls" after ingest despite API returning data. Root cause: three separate `has` state vars (nodes list, edges list, boolean flag) updated across an `await` boundary caused React to render with the flag=true but lists still empty. Fixed by consolidating into a single `has full_graph: dict | None` state that carries both nodes and edges atomically.

## Learnings
- Multiple `has` state updates across `await` boundaries in async handlers can desync in React. Consolidate related data into a single dict/object state to ensure atomic updates.
- `[client.vite]` is the correct jac.toml key for Vite plugins.
- Step indicator state should derive from real backend results, not click events.

## Last Action
Turn 8: Fixed Call Graph rendering bug.
- Consolidated full_graph_nodes + full_graph_edges + graph_loaded into single `full_graph: dict | None` state
- Single atomic state update ensures nodes/edges arrive together
- Verified: ingest /app shows "6 functions, 3 calls" with real graph nodes
