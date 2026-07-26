"""Annex to agent.jac - runs explain_risk() against MockLLM so the wiring
(sem prompts, tool list, typed signature) is verified in `jac test` without
a live API key. Real model behavior is verified separately via `jac start`
+ curl once ANTHROPIC_API_KEY is set (see README).
"""

import from jaclang.byllm.lib { MockLLM }
import from graph { Function }
import from ingest { ingest_repo }

test "explain_risk runs against the graph-grounded blast radius" {
    llm = MockLLM(
        model_name="mockllm",
        config={"outputs": ["This is a low-risk change: only `process` calls `helper` directly, and `main` depends on it transitively. Run tests/test_app.py before merging."]}
    );

    ingest_repo("tests/fixture_repo");

    narrative = explain_risk("helper", ["process", "main"]);

    assert len(narrative) > 0;
    assert "helper" in narrative or "process" in narrative or "risk" in narrative.lower();
}
