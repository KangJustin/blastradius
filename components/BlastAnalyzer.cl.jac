"""Blast Radius Analyzer - restructured IA:
Header / Repo toolbar / Step indicator / Content panels."""

import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.button { Button }
import from .ui.input { Input }
import from .ui.badge { Badge }
import from .ui.spinner { Spinner }
import from .ui.alert { Alert, AlertTitle, AlertDescription }
import from .ui.separator { Separator }
import from ..lib.utils { cn }
import from .GraphCanvas { GraphCanvas }
import from .ContextPanel { ContextPanel }
import from .RiskReport { RiskReport }

glob _NL: str = chr(10);
glob _BT: str = chr(96);

def render_markdown(text: str) -> str {
    lines: list[str] = text.split(_NL);
    html: str = "";
    in_list: bool = False;
    for line in lines {
        stripped: str = line.strip();
        if not stripped {
            if in_list { html = html + "</ul>"; in_list = False; }
            html = html + "<br/>";
            continue;
        }
        if stripped.startswith("### ") {
            if in_list { html = html + "</ul>"; in_list = False; }
            html = html + "<h3 class='text-base font-semibold mt-4 mb-2'>" + apply_inline(stripped[4:]) + "</h3>";
        } elif stripped.startswith("## ") {
            if in_list { html = html + "</ul>"; in_list = False; }
            html = html + "<h2 class='text-lg font-semibold mt-4 mb-2'>" + apply_inline(stripped[3:]) + "</h2>";
        } elif stripped.startswith("# ") {
            if in_list { html = html + "</ul>"; in_list = False; }
            html = html + "<h1 class='text-xl font-bold mt-4 mb-2'>" + apply_inline(stripped[2:]) + "</h1>";
        } elif stripped.startswith("- ") or stripped.startswith("* ") {
            if not in_list { html = html + "<ul class='list-disc pl-6 space-y-1'>"; in_list = True; }
            html = html + "<li>" + apply_inline(stripped[2:]) + "</li>";
        } else {
            if in_list { html = html + "</ul>"; in_list = False; }
            html = html + "<p class='mb-2'>" + apply_inline(stripped) + "</p>";
        }
    }
    if in_list { html = html + "</ul>"; }
    return html;
}

def apply_inline(text: str) -> str {
    result: str = text;
    while "**" in result {
        start: int = result.index("**");
        rest: str = result[start + 2:];
        if "**" not in rest { break; }
        end: int = rest.index("**");
        bold_text: str = rest[:end];
        result = result[:start] + "<strong>" + bold_text + "</strong>" + rest[end + 2:];
    }
    while _BT in result {
        start: int = result.index(_BT);
        rest: str = result[start + 1:];
        if _BT not in rest { break; }
        end: int = rest.index(_BT);
        code_text: str = rest[:end];
        result = result[:start] + "<code class='bg-muted px-1 py-0.5 rounded text-sm'>" + code_text + "</code>" + rest[end + 1:];
    }
    return result;
}

def:pub BlastAnalyzer() -> JsxElement {
    # --- State ---
    has repo_path: str = "";
    has ingesting: bool = False;
    has ingest_result: dict | None = None;
    has ingest_error: str = "";
    has full_graph: dict | None = None;
    has api_ok: bool = True;

    has target_fn: str = "";
    has max_hops: int = 3;
    has computing: bool = False;
    has blast_found: bool = False;
    has blast_reports: list = [];
    has blast_hop_of: dict = {};
    has blast_error: str = "";
    has blast_done: bool = False;
    has view_mode: str = "graph";

    has explaining: bool = False;
    has explanation: str = "";
    has explain_error: str = "";

    # Reveal animation
    has revealed_hops: int = 0;
    has reveal_timer: int = 0;

    # Suggest tests
    has suggested_tests: list = [];
    has tests_loading: bool = False;

    # --- Handlers (unchanged logic) ---

    async def handle_ingest() -> None {
        if not repo_path { return; }
        ingesting = True;
        ingest_error = "";
        ingest_result = None;
        full_graph = None;
        blast_done = False;
        blast_reports = [];
        blast_hop_of = {};
        explanation = "";
        resp = await fetch("/function/ingest_repo", {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({"repo_path": repo_path})
        });
        if not resp.ok {
            body = await resp.text();
            ingest_error = "Ingest failed (" + str(resp.status) + "): " + body;
            ingesting = False;
            api_ok = False;
            return;
        }
        api_ok = True;
        raw = await resp.text();
        parsed = JSON.parse(raw);
        r = parsed["data"]["result"];
        ingest_result = {"files": r["files"], "functions": r["functions"], "calls": r["calls"], "imports": r["imports"], "status": r["status"]};
        g_resp = await fetch("/function/get_graph", {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({})
        });
        if g_resp.ok {
            g_raw = await g_resp.text();
            g_parsed = JSON.parse(g_raw);
            g_result = g_parsed["data"]["result"];
            full_graph = {"nodes": g_result["nodes"], "edges": g_result["edges"]};
        }
        ingesting = False;
    }

    async def handle_blast() -> None {
        if not target_fn { return; }
        computing = True;
        blast_error = "";
        blast_done = False;
        blast_reports = [];
        blast_hop_of = {};
        blast_found = False;
        explanation = "";
        revealed_hops = 0;
        suggested_tests = [];
        tests_loading = False;
        resp = await fetch("/walker/BlastRadius", {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({"target_fn": target_fn, "max_hops": max_hops})
        });
        if not resp.ok {
            body = await resp.text();
            blast_error = "Blast radius failed (" + str(resp.status) + "): " + body;
            computing = False;
            api_ok = False;
            return;
        }
        api_ok = True;
        raw_text = await resp.text();
        data = JSON.parse(raw_text);
        envelope = data["data"];
        walker_result = envelope["result"];
        blast_found = True if walker_result["found"] else False;
        hops = walker_result["hop_of"];
        if hops { blast_hop_of = hops as dict; }
        reps = envelope["reports"];
        if reps {
            blast_reports = reps as list;
        } else {
            reps2 = walker_result["reports"];
            if reps2 { blast_reports = reps2 as list; }
        }
        blast_done = True;
        computing = False;
        # Start reveal animation: stagger by hop
        if blast_found {
            revealed_hops = 0;
            start_reveal();
            # Fire suggest_tests in parallel (non-blocking)
            fire_suggest_tests();
        }
    }

    async def fire_suggest_tests() -> None {
        tests_loading = True;
        affected_names: list[str] = [];
        for r in blast_reports {
            if r { affected_names = affected_names + [str(r["name"])]; }
        }
        resp = await fetch("/function/suggest_tests", {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({"affected": affected_names})
        });
        if resp.ok {
            raw = await resp.text();
            parsed = JSON.parse(raw);
            result = parsed["data"]["result"];
            if result { suggested_tests = result as list; }
        }
        tests_loading = False;
    }

    def start_reveal() {
        # Find max hop in results
        max_h: int = 0;
        for k_raw in blast_hop_of.keys() {
            v = blast_hop_of[k_raw];
            hv: int = int(v) if v else 0;
            if hv > max_h { max_h = hv; }
        }
        # Stagger reveal: increment revealed_hops every 400ms
        hop_idx: int = 0;
        def tick() {
            hop_idx = hop_idx + 1;
            revealed_hops = hop_idx;
            if hop_idx < max_h + 1 {
                setTimeout(tick, 400);
            }
        }
        setTimeout(tick, 200);
    }

    async def handle_explain() -> None {
        if len(blast_reports) == 0 { return; }
        explaining = True;
        explain_error = "";
        explanation = "";
        affected_names: list[str] = [];
        for r in blast_reports {
            if r { affected_names = affected_names + [str(r["name"])]; }
        }
        resp = await fetch("/function/explain_risk", {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({"target": target_fn, "affected": affected_names})
        });
        if not resp.ok {
            body = await resp.text();
            explain_error = "Explain failed (" + str(resp.status) + "): " + body;
            api_ok = False;
        } else {
            api_ok = True;
            data = await resp.json();
            result_val = data?["data"]?["result"];
            if not result_val { result_val = data?["result"]; }
            explanation = str(result_val) if result_val else str(data);
        }
        explaining = False;
    }

    def on_repo_change(e: ChangeEvent) { repo_path = e.target.value; }
    def on_target_change(e: ChangeEvent) { target_fn = e.target.value; }
    def on_hops_change(e: ChangeEvent) {
        val: str = e.target.value;
        try { max_hops = int(val); }
        except Exception { max_hops = 3; }
    }
    def set_hops_from_str(val: str) {
        try { max_hops = int(val); }
        except Exception { max_hops = 3; }
    }

    # --- Derived step states ---
    step1_complete: bool = ingest_result is not None;
    step2_complete: bool = bool(target_fn);
    step3_complete: bool = blast_done and blast_found;

    # --- Render ---

    return <div className="min-h-screen bg-background">
        {#* ==== 1. HEADER ==== *#}
        <header className="border-b bg-card">
            <div className="mx-auto max-w-5xl flex items-center justify-between pt-4 pb-4 pl-4 pr-4 sm:pl-6 sm:pr-6">
                <div className="flex items-center gap-3">
                    <h1 className="text-xl font-bold tracking-tight">BlastRadius</h1>
                    <span className="text-sm text-muted-foreground hidden sm:inline">Agentic code-risk analysis</span>
                </div>
                <div className="flex items-center gap-3">
                    <a
                        href="https://github.com/KangJustin/blastradius"
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-sm text-muted-foreground hover:text-foreground underline-offset-4 hover:underline"
                    >
                        {"GitHub"}
                    </a>
                    <div className="flex items-center gap-1.5" title={"Backend " + ("connected" if api_ok else "error")}>
                        <span className={cn(
                            "inline-block size-2 rounded-full",
                            "bg-emerald-500" if api_ok else "bg-destructive"
                        )} />
                        <span className="text-xs text-muted-foreground">
                            {"API" if api_ok else "Error"}
                        </span>
                    </div>
                </div>
            </div>
        </header>

        <div className="mx-auto max-w-5xl pt-6 pb-12 pl-4 pr-4 sm:pl-6 sm:pr-6">
            {#* ==== 2. REPO TOOLBAR ==== *#}
            <div className="flex flex-col gap-3 mb-6">
                <div className="flex gap-2">
                    <Input
                        placeholder="/absolute/path/to/repo"
                        value={repo_path}
                        onChange={on_repo_change}
                        className="flex-1 font-mono text-sm"
                    />
                    <Button onClick={handle_ingest} disabled={ingesting or not repo_path} size="default">
                        {if ingesting { <><Spinner className="size-4" /> {"Ingesting..."}</> }}
                        {if not ingesting { <>{"Ingest"}</> }}
                    </Button>
                </div>
                {#* Ingest status row *#}
                {if ingest_error {
                    <div className="flex items-center gap-2 rounded-md border border-destructive/50 bg-destructive/5 px-3 py-2 text-sm text-destructive">
                        <span className="inline-block size-2 rounded-full bg-destructive" />
                        {ingest_error}
                    </div>
                }}
                {if ingesting {
                    <div className="flex items-center gap-2 rounded-md border px-3 py-2 text-sm text-muted-foreground">
                        <Spinner className="size-3.5" />
                        {"Parsing repository..."}
                    </div>
                }}
                {if ingest_result and not ingesting {
                    <div className="flex items-center gap-2 flex-wrap">
                        <span className="inline-block size-2 rounded-full bg-emerald-500" />
                        <span className="text-sm text-muted-foreground mr-1">{"Ingested"}</span>
                        <Badge variant="secondary" className="text-xs tabular-nums">{str(ingest_result["files"]) + " files"}</Badge>
                        <Badge variant="secondary" className="text-xs tabular-nums">{str(ingest_result["functions"]) + " functions"}</Badge>
                        <Badge variant="secondary" className="text-xs tabular-nums">{str(ingest_result["calls"]) + " calls"}</Badge>
                        <Badge variant="secondary" className="text-xs tabular-nums">{str(ingest_result["imports"]) + " imports"}</Badge>
                    </div>
                }}
            </div>

            {#* ==== 3. WORKFLOW STEP INDICATOR ==== *#}
            <div className="flex items-center gap-0 mb-8 rounded-lg border bg-card p-1">
                {#* Step 1 *#}
                <div className={cn(
                    "flex-1 flex items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors",
                    "bg-primary/10 text-foreground" if step1_complete else (
                        "bg-muted/50 text-foreground" if ingesting else "text-muted-foreground"
                    )
                )}>
                    <span className={cn(
                        "inline-flex items-center justify-center size-5 rounded-full text-[10px] font-bold shrink-0",
                        "bg-primary text-primary-foreground" if step1_complete else "bg-muted-foreground/20 text-muted-foreground"
                    )}>
                        {"1" if not step1_complete else ""}
                        {if step1_complete {
                            <svg viewBox="0 0 12 12" className="size-3 fill-current"><path d="M10 3L4.5 8.5 2 6" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" /></svg>
                        }}
                    </span>
                    <span className="font-medium">{"Ingest"}</span>
                </div>
                <Separator orientation="vertical" className="h-5" />
                {#* Step 2 *#}
                <div className={cn(
                    "flex-1 flex items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors",
                    "bg-primary/10 text-foreground" if step2_complete else "text-muted-foreground"
                )}>
                    <span className={cn(
                        "inline-flex items-center justify-center size-5 rounded-full text-[10px] font-bold shrink-0",
                        "bg-primary text-primary-foreground" if step2_complete else "bg-muted-foreground/20 text-muted-foreground"
                    )}>
                        {"2" if not step2_complete else ""}
                        {if step2_complete {
                            <svg viewBox="0 0 12 12" className="size-3 fill-current"><path d="M10 3L4.5 8.5 2 6" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" /></svg>
                        }}
                    </span>
                    <span className="font-medium">{"Select function"}</span>
                    {if step2_complete {
                        <Badge variant="outline" className="text-xs ml-auto">{target_fn}</Badge>
                    }}
                </div>
                <Separator orientation="vertical" className="h-5" />
                {#* Step 3 *#}
                <div className={cn(
                    "flex-1 flex items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors",
                    "bg-primary/10 text-foreground" if step3_complete else (
                        "bg-muted/50 text-foreground" if computing else "text-muted-foreground"
                    )
                )}>
                    <span className={cn(
                        "inline-flex items-center justify-center size-5 rounded-full text-[10px] font-bold shrink-0",
                        "bg-primary text-primary-foreground" if step3_complete else "bg-muted-foreground/20 text-muted-foreground"
                    )}>
                        {"3" if not step3_complete else ""}
                        {if step3_complete {
                            <svg viewBox="0 0 12 12" className="size-3 fill-current"><path d="M10 3L4.5 8.5 2 6" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" /></svg>
                        }}
                    </span>
                    <span className="font-medium">{"Analyze impact"}</span>
                    {if step3_complete {
                        <Badge variant="outline" className="text-xs ml-auto">{str(len(blast_reports)) + " affected"}</Badge>
                    }}
                </div>
            </div>

            {#* ==== CONTENT PANELS ==== *#}
            <div className="flex flex-col gap-6">
                {#* Full Call Graph *#}
                {if full_graph {
                    <Card>
                        <CardHeader>
                            <div className="flex items-center gap-2">
                                <CardTitle>Call Graph</CardTitle>
                                <Badge variant="secondary">{str(len(full_graph["nodes"] as list)) + " functions, " + str(len(full_graph["edges"] as list)) + " calls"}</Badge>
                            </div>
                            <CardDescription>Click a node to select it as the blast-radius target.</CardDescription>
                        </CardHeader>
                        <CardContent>
                            <GraphCanvas mode="full" graph_nodes={full_graph["nodes"] as list} graph_edges={full_graph["edges"] as list} on_select={lambda (fn_name: str) { target_fn = fn_name; }} />
                        </CardContent>
                    </Card>
                }}

                {#* Context Panel (pre/post analysis) *#}
                {if target_fn {
                    <ContextPanel
                        target_fn={target_fn}
                        full_graph={full_graph}
                        blast_done={blast_done}
                        blast_found={blast_found}
                        blast_reports={blast_reports}
                        blast_hop_of={blast_hop_of}
                        blast_error={blast_error}
                        computing={computing}
                        max_hops={max_hops}
                        on_hops_change={set_hops_from_str}
                        on_analyze={handle_blast}
                        revealed_hops={revealed_hops}
                        suggested_tests={suggested_tests}
                        tests_loading={tests_loading}
                    />
                }}

                {#* Blast Radius Graph (post-analysis) *#}
                {if blast_done and blast_found {
                    <Card>
                        <CardHeader>
                            <div className="flex items-center justify-between">
                                <div className="flex items-center gap-2">
                                    <CardTitle>Impact Graph</CardTitle>
                                    <Badge variant="secondary">{str(len(blast_reports)) + " affected"}</Badge>
                                </div>
                                <div className="flex items-center gap-2">
                                    <div className="flex rounded-md border overflow-hidden">
                                        <button className={cn("px-3 py-1 text-sm", "bg-primary text-primary-foreground" if view_mode == "graph" else "bg-background text-muted-foreground hover:text-foreground")}
                                            onClick={lambda (e: MouseEvent) { view_mode = "graph"; }}>{"Graph"}</button>
                                        <button className={cn("px-3 py-1 text-sm border-l", "bg-primary text-primary-foreground" if view_mode == "list" else "bg-background text-muted-foreground hover:text-foreground")}
                                            onClick={lambda (e: MouseEvent) { view_mode = "list"; }}>{"List"}</button>
                                    </div>
                                </div>
                            </div>
                        </CardHeader>
                        <CardContent>
                            {if view_mode == "graph" { <GraphCanvas mode="blast" target_fn={target_fn} reports={blast_reports} hop_of={blast_hop_of} /> }}
                            {if view_mode == "list" { <BlastResultsList reports={blast_reports} hop_of={blast_hop_of} /> }}
                        </CardContent>
                    </Card>
                }}

                {#* Fallback: function input when no graph click available *#}
                {if not target_fn and ingest_result {
                    <Card>
                        <CardContent className="pt-4">
                            <div className="flex gap-2">
                                <Input placeholder="function_name" value={target_fn} onChange={on_target_change} className="flex-1 font-mono text-sm" />
                                <Button onClick={handle_blast} disabled={computing or not target_fn}>{"Analyze"}</Button>
                            </div>
                        </CardContent>
                    </Card>
                }}

                {#* Risk Report *#}
                {if blast_done and blast_found {
                    <RiskReport target_fn={target_fn} affected={blast_reports} />
                }}
            </div>
        </div>
    </div>;
}

def:pub BlastResultsList(reports: list, hop_of: dict) -> JsxElement {
    hop_groups: dict[str, list] = {};
    for r in reports {
        if not r { continue; }
        fn_name: str = str(r["name"]);
        hop: str = str(hop_of?[fn_name]) if hop_of?[fn_name] else "0";
        if hop not in hop_groups { hop_groups[hop] = []; }
        hop_groups[hop] = hop_groups[hop] + [r];
    }
    sorted_hops: list = sorted(hop_groups.keys());
    if len(reports) == 0 {
        return <Alert><AlertTitle>No affected functions</AlertTitle><AlertDescription>No functions were found in the blast radius.</AlertDescription></Alert>;
    }
    return <div className="flex flex-col gap-4">
        {for hop in sorted_hops {
            <div key={str(hop)} className="flex flex-col gap-2">
                <div className="flex items-center gap-2">
                    <Badge variant="outline">{"Hop " + str(hop)}</Badge>
                    <span className="text-sm text-muted-foreground">{str(len(hop_groups[str(hop)])) + " function" + ("s" if len(hop_groups[str(hop)]) != 1 else "")}</span>
                </div>
                <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                    {for fn_item in hop_groups[str(hop)] {
                        <div key={str(fn_item["name"])} className="flex flex-col gap-1 rounded-md border p-4">
                            <span className="font-medium">{fn_item["name"]}</span>
                            <span className="text-sm text-muted-foreground">{fn_item["file"]}</span>
                        </div>
                    }}
                </div>
            </div>
        }}
    </div>;
}
