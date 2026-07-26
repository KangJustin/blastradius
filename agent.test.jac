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

test "read_source returns the real source for a known function" {
    ingest_repo("tests/fixture_repo");

    src = read_source("helper");

    assert "return 1" in src;
}

test "read_source reports missing functions clearly instead of erroring" {
    ingest_repo("tests/fixture_repo");

    src = read_source("does_not_exist");

    assert "no source on file" in src;
}

test "suggest_tests guesses conventional test paths for real functions" {
    ingest_repo("tests/fixture_repo");

    paths = suggest_tests(["process"]);

    assert paths == ["tests/test_app.py"];
}

test "suggest_tests skips functions not in the graph" {
    ingest_repo("tests/fixture_repo");

    paths = suggest_tests(["process", "does_not_exist"]);

    assert paths == ["tests/test_app.py"];
}
