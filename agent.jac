"""The explainer agent: turns a raw blast-radius result (real graph nodes,
computed by walker traversal in blastradius.jac) into a structured risk
assessment, with a tool that lets the model pull more graph context before
answering instead of guessing. f"suggest_tests" is deterministic (naming-
convention lookup, not an LLM call) and is exposed as its own endpoint so
the frontend can fetch it independently of - and even if - explain_risk
fails.
"""

import from graph { Function }
import from jaclang.byllm.lib { Model }

glob llm: any = Model(model_name="claude-sonnet-4-6");

def read_source(fn_name: str) -> str {
    matches = [root -->[?:Function, name == fn_name]];
    if len(matches) == 0 {
        return "(no source on file for " + fn_name + ")";
    }
    fn: Function = matches[0] as Function;
    return fn.source;
}
sem read_source = "Read the full source snippet of a function already in the graph, by its exact name.";
sem read_source.fn_name = "Exact function name to look up.";

def:pub suggest_tests(affected: list[str]) -> list[str] {
    out: list[str] = [];
    for target_name in affected {
        matches = [root -->[?:Function, name == target_name]];
        if len(matches) == 0 {
            continue;
        }
        fn: Function = matches[0] as Function;

        idx: int = fn.file.rfind("/");
        base: str = fn.file[idx + 1:] if idx >= 0 else fn.file;
        base = base[:-3] if base.endswith(".py") else base;
        dirname: str = fn.file[:idx] if idx >= 0 else "";
        candidate: str = (dirname + "/tests/test_" + base + ".py") if dirname != "" else ("tests/test_" + base + ".py");
        out.append(candidate);
    }
    return out;
}
sem suggest_tests = "Guess likely test file paths, by naming convention, for a list of affected function names.";
sem suggest_tests.affected = "Function names whose owning file's likely test path should be guessed.";

obj RiskAssessment {
    has summary: str;
    has why_risky: str;
    has could_break: str;
    has severity: str;
}
sem RiskAssessment = "A structured risk assessment for a function about to be changed, split into scannable sections instead of one paragraph.";
sem RiskAssessment.summary = "1-2 sentences: what the target function does.";
sem RiskAssessment.why_risky = "1-2 sentences: why changing it carries risk, grounded in the real callers/callees it has.";
sem RiskAssessment.could_break = "1-3 sentences: concretely what could break downstream.";
sem RiskAssessment.severity = "The single word 'low', 'medium', or 'high' - nothing else, no explanation, no punctuation. Based on how many functions are affected and how central the target is to the call graph.";

def _explain_risk_llm(target: str, affected: list[str]) -> RiskAssessment by llm(
    tools=[read_source]
);
sem _explain_risk_llm = "The functions in affected are the real blast radius of changing target. Fill out a structured risk assessment. Use read_source to see function bodies. Keep every field concise.";
sem _explain_risk_llm.target = "Name of the function about to be changed.";
sem _explain_risk_llm.affected = "Names of functions in the blast radius, already computed by graph traversal - ground truth, not a guess.";

def:pub explain_risk(target: str, affected: list[str]) -> RiskAssessment {
    raw: RiskAssessment = _explain_risk_llm(target, affected);
    lowered: str = raw.severity.lower();
    severity: str = "medium";
    if "high" in lowered {
        severity = "high";
    } elif "low" in lowered {
        severity = "low";
    } elif "medium" in lowered {
        severity = "medium";
    }
    return RiskAssessment(
        summary=raw.summary,
        why_risky=raw.why_risky,
        could_break=raw.could_break,
        severity=severity
    );
}
