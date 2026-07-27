## Issues
- [turn 6] Git revert wiped components/styles/lib dirs. Restored all files. Duplicate [client.vite] in jac.toml caused TOML parse error. Fixed by deduplicating.
- [turn 6] Sandbox pod expiry caused white screen - just needed preview restart, files were intact.

## Learnings
- `[client.vite]` is the correct jac.toml key for Vite plugins (not `[plugins.client.vite]`).
- Never have duplicate TOML sections - causes silent `MalformedJacTomlError`.
- White screen on fresh sandbox = JS still loading, wait 5s before diagnosing.
- Step indicator state should derive from real backend results, not click events.

## Last Action
Turn 7: Restructured app IA into Header / Repo toolbar / Step indicator.
- Header: BlastRadius wordmark, subtitle, GitHub link, live API connection dot
- Repo toolbar: compact input + ingest with 3 explicit states (empty/loading/success with badges)
- Step indicator: 3-step bar reflecting real backend state (ingest success, fn selected, blast done)
- No backend changes. CallGraph/FullGraph untouched.
- All 3 ingest states verified against real backend.
