## Issues
- [turn 9] Node click closure bug fixed: replaced inline lambdas in for-loop with delegated click handler using data-fn attributes on SVG elements + single onClick on parent SVG. e.target walks up to find data-fn.

## Learnings
- Delegated event handling (data-* attributes + parent onClick) fixes the for-loop lambda closure bug in Jac JSX SVG rendering.
- `el.parentElement` returns `HTMLElement | None` in Jac type system - cast with `as any`.
- Nested `{for ...}` inside `{if ...}` in JSX slots is redundant wrapping - drop the inner braces.
- Consolidate related state into single dict to avoid async desync across await boundaries.

## Last Action
Turn 9: Merged FullGraph + CallGraph into unified GraphCanvas.cl.jac.
- Single component with mode="full"|"blast" prop
- Fixed node-click bug with delegated data-fn handler (verified: clicking _module_path correctly sets target_fn and updates step indicator)
- Added zoom controls: +, -, Fit (bounding-box), 1:1 reset
- Added hover tooltip: function name, file:line, caller/callee counts (computed client-side from edge data)
- Updated graphdata.jac to include line number in node data
- Deleted old FullGraph.cl.jac and CallGraph.cl.jac
- Updated BlastAnalyzer.cl.jac to use GraphCanvas for both full and blast modes
