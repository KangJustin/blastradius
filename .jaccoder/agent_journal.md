## Issues
- [turn 11] Backticks in sem strings get mangled to f-strings by auto-fix. Removed backticks from sem descriptions.
- [turn 11] agent.test.jac has type errors from RiskAssessment change (pre-existing test file, not blocking).

## Learnings
- Backticks in string literals are special in Jac (keyword escaping). Avoid them in sem strings.
- RiskAssessment obj with sem annotations enables structured LLM output with typed fields.
- Severity normalization should happen server-side (in the wrapper def:pub), not trusted from LLM output.

## Last Action
Turn 11: Phase 4 - RiskReport component + structured explain_risk.
- Replaced agent.jac with RiskAssessment struct version (summary, why_risky, could_break, severity)
- explain_risk now returns RiskAssessment with normalized severity (low/medium/high)
- Created RiskReport.cl.jac with 5 states: empty, not-requested, loading (skeleton), error (retry), success (structured report)
- Severity badge: colored pill (emerald/yellow/red) for low/medium/high
- Scannable sections: Summary, Why risky, What could break
- Collapsed "Detailed explanation" section
- Data source labels: graph traversal vs AI-generated
- Wired into BlastAnalyzer, removed old Explanation section and Explain Risk button
- Registered RiskAssessment in main.jac imports
