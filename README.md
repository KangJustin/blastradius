# BlastRadius

An agentic code-risk analyst, built in [Jac](https://www.jaseci.org/): point it at a real
repository, name a function you're about to change, and a Jac **walker**
traverses the real call graph to compute exactly what's downstream - then an
LLM agent explains the risk in plain English and suggests which tests to run
first.

Built for **JacHacks SF 2026**. See the full strategy doc (ideas, ranking,
demo script, timeline) for context on why this project was chosen.

## Why this is meaningfully Jac, not Jac-flavored Python

- The **graph is the data model**: `File`/`Function` nodes, `Calls`/`Imports`
  edges (`graph.jac`) - not a list dressed up as a graph.
- The **`BlastRadius` walker** (`blastradius.jac`) makes real traversal
  decisions at runtime (bounded by hop count, guarded against cycles) - not a
  fixed script.
- **`ingest_repo`** (`ingest.jac`) is deliberately a `def:pub` function, not a
  walker - it builds the graph rather than walking it, per Jac's own
  endpoint-shape rule. `explain_risk` (`agent.jac`) is a typed `by llm()` call
  with real tool-calling (`read_source`, `suggest_tests`), grounded in the
  walker's actual output - the model is told explicitly to trust the graph's
  own traversal, not to re-derive or guess it.
- Everything through `jac start` - REST endpoints, Swagger docs, persistence
  - is generated from this same code. There is no separate backend.

## Project layout

```
blastradius/
├── jac.toml              # [byllm.model] config; [test] defaults
├── main.sv.jac           # entry point - imports every public endpoint by name
├── graph.jac             # File/Function nodes, Imports/Calls edges
├── parser.py             # stdlib-ast-based repo parser (Python, no deps)
├── ingest.jac             # def:pub ingest_repo(repo_path) -> IngestResult
├── blastradius.jac       # walker:pub BlastRadius(target_fn, max_hops)
├── agent.jac             # def:pub explain_risk(...) by llm(tools=[...])
├── ingest_and_walker_tests.jac   # deterministic graph/walker tests
├── agent.test.jac        # explain_risk tested via MockLLM (no API key needed)
└── tests/fixture_repo/   # tiny repo with a known call chain, used by tests
```

## Setup

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
export PATH="$HOME/.local/bin:$PATH"

cd blastradius
jac install                        # resolves byLLM/litellm etc into .jac/venv
export ANTHROPIC_API_KEY="sk-ant-..."   # required for explain_risk to actually call a model
```

## Run the tests

```bash
jac clean --data --force   # graph state persists across runs - start clean
jac test                   # 7 tests: parser+ingest+walker (real), explain_risk (MockLLM)
```

## Run it for real

```bash
jac start main.sv.jac --no-client --port 8010
```

```bash
# Ingest any real repo - including this one:
curl -s -X POST http://localhost:8010/function/ingest_repo \
  -H "Content-Type: application/json" \
  -d '{"repo_path": "/absolute/path/to/some/repo"}'

# Compute the blast radius of changing one function:
curl -s -X POST http://localhost:8010/walker/BlastRadius \
  -H "Content-Type: application/json" \
  -d '{"target_fn": "some_function_name", "max_hops": 3}'

# Ask the agent to explain the risk (needs ANTHROPIC_API_KEY set above):
curl -s -X POST http://localhost:8010/function/explain_risk \
  -H "Content-Type: application/json" \
  -d '{"target": "some_function_name", "affected": ["caller_one", "caller_two"]}'
```

Swagger docs: `http://localhost:8010/docs`. Live graph view: `http://localhost:8010/graph`.

Verified end-to-end against this repo's own `parser.py`: ingesting
`~/blastradius` and asking for the blast radius of `_module_path` correctly
returns `_module_path` and its one real caller, `parse_repo`.

## Using JacHammer (jachammer.ai)

The **Best JacHammer** track judges whether you actually built in
[jachammer.ai](https://jachammer.ai/), Jaseci Labs' browser IDE. To mirror
this project there for track eligibility:

1. Create a new project in JacHammer.
2. Copy in `graph.jac`, `parser.py`, `ingest.jac`, `blastradius.jac`,
   `agent.jac`, `main.sv.jac` (paste as-is - no changes needed).
3. Set the same `[byllm.model]` config and `ANTHROPIC_API_KEY`.
4. Confirm JacHammer's preview actually serves these endpoints (its exact
   preview/versioning mechanics aren't publicly documented - budget a couple
   of minutes to learn its UI at check-in rather than assuming).

This repo is the source of truth / local development + test environment;
JacHammer is the track-eligible build surface for submission.

## Known limitations (scoped out deliberately, see the strategy doc)

- `parser.py` resolves calls by **name only** (no full static analysis) -
  fine for a small demo repo, ambiguous on repos with many same-named
  functions.
- Only direct `ast.Call` targets are tracked (`foo()`, `obj.foo()`); dynamic
  dispatch and decorators that rewrite call sites aren't followed.
- Only `.py` files are parsed.
