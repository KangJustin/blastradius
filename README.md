# BlastRadius

An agentic code-risk analyst, built in [Jac](https://www.jaseci.org/): point it at a real
repository, click a function you're about to change, and a Jac **walker**
traverses the real call graph to compute exactly what's downstream - then an
LLM agent explains the risk in plain English and suggests which tests to run
first. The UI always labels which is which: **computed from graph traversal**
(affected functions, suggested tests) versus **AI-generated explanation**
(the risk narrative and severity).

Built for **JacHacks SF 2026**.

## Why this is meaningfully Jac, not Jac-flavored Python

- The **graph is the data model**: `File`/`Function` nodes, `Calls`/`Imports`
  edges (`graph.jac`) - not a list dressed up as a graph.
- The **`BlastRadius` walker** (`blastradius.jac`) makes real traversal
  decisions at runtime (bounded by hop count, guarded against cycles) - not a
  fixed script.
- **`ingest_repo`** (`ingest.jac`) is deliberately a `def:pub` function, not a
  walker - it builds the graph rather than walking it, per Jac's own
  endpoint-shape rule. `explain_risk` (`agent.jac`) is a typed `by llm()` call
  returning a structured `RiskAssessment`, with real tool-calling
  (`read_source`) grounded in the walker's actual output - the model is told
  explicitly to trust the graph's own traversal, not to re-derive or guess it.
  `suggest_tests` is deterministic (naming-convention lookup, not an LLM call)
  and exposed as its own endpoint so the frontend can show it even if
  `explain_risk` fails.
- It's a **fullstack Jac app**: the same language defines the graph, the
  walker, the agent, the REST endpoints, and the client UI (`.cl.jac`
  components) in one codebase - no separate frontend repo or hand-written API
  glue.

## Project layout

```
blastradius/
├── jac.toml                     # kind = "fullstack"; entry-point = "main.jac"
├── main.jac                     # entry point - registers backend endpoints, renders <BlastAnalyzer />
├── graph.jac                    # File/Function nodes, Imports/Calls edges
├── parser.py                    # stdlib-ast-based repo parser (Python, no deps)
├── ingest.jac                   # def:pub ingest_repo(repo_path) -> IngestResult
├── blastradius.jac              # walker:pub BlastRadius(target_fn, max_hops)
├── agent.jac                    # def:pub explain_risk(...) -> RiskAssessment, suggest_tests(...)
├── graphdata.jac                # def:pub get_graph() -> GraphData, for the graph view
├── components/
│   ├── BlastAnalyzer.cl.jac     # top-level layout: ingest -> select -> analyze
│   ├── GraphCanvas.cl.jac       # interactive call-graph visualization
│   ├── ContextPanel.cl.jac      # suggested tests + affected-functions list
│   ├── RiskReport.cl.jac        # severity badge, risk sections, detailed explanation
│   └── ui/                      # shadcn-style primitives (badge, card, button, ...)
├── lib/utils.jac                # shared client-side helpers
├── styles/global.css            # Tailwind entry
├── ingest_and_walker_tests.jac  # deterministic graph/walker tests
├── agent.test.jac               # explain_risk tested via MockLLM (no API key needed)
└── tests/fixture_repo/          # tiny repo with a known call chain, used by tests
```

## Setup

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
export PATH="$HOME/.local/bin:$PATH"

cd blastradius
jac install                        # resolves byLLM/litellm + npm deps (tailwind, shadcn, etc.)
export ANTHROPIC_API_KEY="sk-ant-..."   # required for explain_risk to actually call a model
```

## Run the tests

```bash
jac clean --data --force   # graph state persists across runs - start clean
jac test                   # parser+ingest+walker (real), explain_risk (MockLLM, no API key needed)
```

## Run it for real

```bash
jac start --dev main.jac
```

This starts the fullstack app - UI and API together. Open the printed local
URL and walk through the three steps: **Ingest** a repo path, **select a
function** (click a node in the graph, or type a name directly), then
**analyze impact** to see the computed blast radius and the AI-generated
`RiskReport`.

The same endpoints are also reachable directly (swap in the port the dev
server printed on startup):

```bash
curl -s -X POST http://localhost:<port>/function/ingest_repo \
  -H "Content-Type: application/json" \
  -d '{"repo_path": "/absolute/path/to/some/repo"}'

curl -s -X POST http://localhost:<port>/walker/BlastRadius \
  -H "Content-Type: application/json" \
  -d '{"target_fn": "some_function_name", "max_hops": 3}'

curl -s -X POST http://localhost:<port>/function/explain_risk \
  -H "Content-Type: application/json" \
  -d '{"target": "some_function_name", "affected": ["caller_one", "caller_two"]}'
```

Swagger docs are served alongside the app.

## Built in JacHammer (jachammer.ai)

This project was built and iterated on directly in
[jachammer.ai](https://jachammer.ai/), Jaseci Labs' browser IDE, for the
**Best JacHammer** track - this repo is that project's synced source of
truth, not a manual mirror.

## Known limitations (scoped out deliberately)

- `parser.py` resolves calls by **name only** (no full static analysis) -
  fine for a small demo repo, ambiguous on repos with many same-named
  functions.
- Only direct `ast.Call` targets are tracked (`foo()`, `obj.foo()`); dynamic
  dispatch and decorators that rewrite call sites aren't followed.
- Only `.py` files are parsed.
- **Local tool, not hosted SaaS**: `ingest_repo` reads a filesystem path on
  whatever machine the server is running on. The intended usage is running
  BlastRadius locally (`jac start --dev main.jac`) against your own repo on
  disk - like a linter, not a hosted app you paste a GitHub URL into. A
  deployed instance can't ingest an arbitrary visitor's repo without an
  upload/clone step that doesn't exist yet.
