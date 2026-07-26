"""The explainer agent: turns a raw blast-radius result (real graph nodes,
computed by walker traversal in blastradius.jac) into a plain-English risk
narrative, with two tools that let the model pull more graph context before
answering instead of guessing.
"""

import from graph { Function }
import from jaclang.byllm.lib { Model }

glob llm = Model(model_name="claude-sonnet-4-6");

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

def suggest_tests(affected: list[str]) -> list[str] {
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

def:pub explain_risk(target: str, affected: list[str]) -> str by llm(
    tools=[read_source, suggest_tests]
);
sem explain_risk = "The functions in `affected` are the real, already-computed blast radius of changing `target` (from a graph traversal over actual call edges - trust this list completely, never re-derive or second-guess which functions are affected). Explain the risk of changing `target` in plain English for a developer who is about to touch it: what could break, roughly how severe, and what to check first. Use read_source if you need to see a specific function's body before judging its risk. Use suggest_tests to recommend concrete test files to run before merging. Keep it under 150 words.";
sem explain_risk.target = "Name of the function about to be changed.";
sem explain_risk.affected = "Names of functions in the blast radius, already computed by graph traversal - ground truth, not a guess.";
