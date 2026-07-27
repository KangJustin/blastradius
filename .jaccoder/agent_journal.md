## Issues
- [turn 10] suggest_tests endpoint registered. ContextPanel created with pre/post analysis states. Reveal animation timer has stale closure on hop_idx (setTimeout + closure). suggest_tests client fetch may silently fail due to same async closure issue.

## Learnings
- `def:pub` on an existing function + adding to main.jac import registers a new endpoint.
- setTimeout callbacks in Jac client code have closure issues with mutable locals - need Ref pattern or state-based approach.
- Consolidate related async state updates into single dict to avoid desync.

## Last Action
Turn 10: Added ContextPanel + suggest_tests endpoint + reveal animation.
- Made suggest_tests def:pub in agent.jac, registered in main.jac
- Created ContextPanel.cl.jac with pre-analysis (fn details, callers/callees, source, analyze button) and post-analysis (affected count, max hop, severity placeholder, suggested tests) states
- Added reveal animation with setTimeout stagger (hop_idx closure issue - shows hop 0)
- Added fire_suggest_tests parallel fetch
- Verified: suggest_tests endpoint returns real test paths via curl
- Verified: ContextPanel shows real callers/callees/source from graph data
- Known issues: reveal counter stuck at hop 0 (closure), suggest_tests may not render in UI (async closure)
