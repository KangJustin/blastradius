"""Blast Radius Analyzer - single-page UI with three sequential steps:
1. Ingest a repo  2. Compute blast radius  3. Explain risk."""

import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.button { Button }
import from .ui.input { Input }
import from .ui.badge { Badge }
import from .ui.spinner { Spinner }
import from .ui.alert { Alert, AlertTitle, AlertDescription }
import from .ui.separator { Separator }
import from ..lib.utils { cn }
import from .CallGraph { CallGraph }
import from .FullGraph { FullGraph }

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
    has repo_path: str = "";
    has ingesting: bool = False;
    has ingest_result: dict | None = None;
    has ingest_error: str = "";
    has full_graph_nodes: list = [];
    has full_graph_edges: list = [];
    has graph_loaded: bool = False;

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

    async def handle_ingest() -> None {
        if not repo_path { return; }
        ingesting = True;
        ingest_error = "";
        ingest_result = None;
        full_graph_nodes = [];
        full_graph_edges = [];
        graph_loaded = False;
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
            return;
        }
        raw = await resp.text();
        parsed = JSON.parse(raw);
        r = parsed["data"]["result"];
        ingest_result = {"files": r["files"], "functions": r["functions"], "calls": r["calls"], "imports": r["imports"], "status": r["status"]};
        # Fetch the full graph
        g_resp = await fetch("/function/get_graph", {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({})
        });
        if g_resp.ok {
            g_raw = await g_resp.text();
            g_parsed = JSON.parse(g_raw);
            g_result = g_parsed["data"]["result"];
            full_graph_nodes = g_result["nodes"] as list;
            full_graph_edges = g_result["edges"] as list;
            graph_loaded = True;
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
        resp = await fetch("/walker/BlastRadius", {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({"target_fn": target_fn, "max_hops": max_hops})
        });
        if not resp.ok {
            body = await resp.text();
            blast_error = "Blast radius failed (" + str(resp.status) + "): " + body;
            computing = False;
            return;
        }
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
        } else {
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

    return <div className="min-h-screen bg-background">
        <div className="mx-auto max-w-4xl pt-12 pb-12 pl-4 pr-4 sm:pl-6 sm:pr-6">
            <div className="flex flex-col gap-2 mb-8">
                <h1 className="text-balance text-3xl font-bold tracking-tight">Blast Radius Analyzer</h1>
                <p className="text-lg text-muted-foreground">Understand the impact of changing any function in your codebase.</p>
            </div>
            <div className="flex flex-col gap-8">
                {#* Step 1: Ingest *#}
                <Card>
                    <CardHeader>
                        <div className="flex items-center gap-2">
                            <Badge variant="outline">Step 1</Badge>
                            <CardTitle>Ingest Repository</CardTitle>
                        </div>
                        <CardDescription>Provide the absolute path to a repository on this server to parse its call graph.</CardDescription>
                    </CardHeader>
                    <CardContent>
                        <div className="flex flex-col gap-4">
                            <div className="flex gap-2">
                                <Input placeholder="/path/to/your/repo" value={repo_path} onChange={on_repo_change} className="flex-1" />
                                <Button onClick={handle_ingest} disabled={ingesting or not repo_path}>
                                    {if ingesting { <><Spinner className="size-4" /> {"Ingesting..."}</> }}
                                    {if not ingesting { <>{"Ingest"}</> }}
                                </Button>
                            </div>
                            {if ingest_error {
                                <Alert><AlertTitle>Error</AlertTitle><AlertDescription>{ingest_error}</AlertDescription></Alert>
                            }}
                            {if ingest_result {
                                <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
                                    <div className="flex flex-col gap-1 rounded-md border p-4">
                                        <span className="text-sm text-muted-foreground">Files</span>
                                        <span className="text-2xl font-semibold tabular-nums">{ingest_result["files"]}</span>
                                    </div>
                                    <div className="flex flex-col gap-1 rounded-md border p-4">
                                        <span className="text-sm text-muted-foreground">Functions</span>
                                        <span className="text-2xl font-semibold tabular-nums">{ingest_result["functions"]}</span>
                                    </div>
                                    <div className="flex flex-col gap-1 rounded-md border p-4">
                                        <span className="text-sm text-muted-foreground">Calls</span>
                                        <span className="text-2xl font-semibold tabular-nums">{ingest_result["calls"]}</span>
                                    </div>
                                    <div className="flex flex-col gap-1 rounded-md border p-4">
                                        <span className="text-sm text-muted-foreground">Imports</span>
                                        <span className="text-2xl font-semibold tabular-nums">{ingest_result["imports"]}</span>
                                    </div>
                                </div>
                            }}
                        </div>
                    </CardContent>
                </Card>

                {#* Full Call Graph *#}
                {if graph_loaded {
                    <Card>
                        <CardHeader>
                            <div className="flex items-center gap-2">
                                <CardTitle>Call Graph</CardTitle>
                                <Badge variant="secondary">{str(len(full_graph_nodes)) + " functions, " + str(len(full_graph_edges)) + " calls"}</Badge>
                            </div>
                            <CardDescription>Full call graph of the ingested repository. Click a node to select it as the blast-radius target below.</CardDescription>
                        </CardHeader>
                        <CardContent>
                            <FullGraph graph_nodes={full_graph_nodes} graph_edges={full_graph_edges} on_select_fn={lambda (fn_name: str) { target_fn = fn_name; }} />
                        </CardContent>
                    </Card>
                }}

                {#* Step 2: Blast Radius *#}
                <Card className={cn("transition-opacity", "" if ingest_result else "opacity-50 pointer-events-none")}>
                    <CardHeader>
                        <div className="flex items-center gap-2">
                            <Badge variant="outline">Step 2</Badge>
                            <CardTitle>Compute Blast Radius</CardTitle>
                        </div>
                        <CardDescription>Enter a function name to find all functions that could be affected by changing it.</CardDescription>
                    </CardHeader>
                    <CardContent>
                        <div className="flex flex-col gap-4">
                            <div className="flex gap-2">
                                <Input placeholder="function_name" value={target_fn} onChange={on_target_change} className="flex-1" />
                                <Input type="number" value={str(max_hops)} onChange={on_hops_change} className="w-24" placeholder="Hops" />
                                <Button onClick={handle_blast} disabled={computing or not target_fn}>
                                    {if computing { <><Spinner className="size-4" /> {"Computing..."}</> }}
                                    {if not computing { <>{"Analyze"}</> }}
                                </Button>
                            </div>
                            {if blast_error { <Alert><AlertTitle>Error</AlertTitle><AlertDescription>{blast_error}</AlertDescription></Alert> }}
                            {if blast_done and not blast_found {
                                <Alert><AlertTitle>Function not found</AlertTitle>
                                    <AlertDescription>{"The function \"" + target_fn + "\" was not found in the ingested graph."}</AlertDescription>
                                </Alert>
                            }}
                            {if blast_done and blast_found {
                                <div className="flex flex-col gap-6">
                                    <div className="flex items-center justify-between">
                                        <div className="flex items-center gap-2">
                                            <h3 className="text-lg font-semibold">Blast Radius</h3>
                                            <Badge variant="secondary">{str(len(blast_reports)) + " functions affected"}</Badge>
                                        </div>
                                        <div className="flex items-center gap-2">
                                            <div className="flex rounded-md border overflow-hidden">
                                                <button className={cn("px-3 py-1 text-sm", "bg-primary text-primary-foreground" if view_mode == "graph" else "bg-background text-muted-foreground hover:text-foreground")}
                                                    onClick={lambda (e: MouseEvent) { view_mode = "graph"; }}>{"Graph"}</button>
                                                <button className={cn("px-3 py-1 text-sm border-l", "bg-primary text-primary-foreground" if view_mode == "list" else "bg-background text-muted-foreground hover:text-foreground")}
                                                    onClick={lambda (e: MouseEvent) { view_mode = "list"; }}>{"List"}</button>
                                            </div>
                                            <Button onClick={handle_explain} disabled={explaining} variant="outline">
                                                {if explaining { <><Spinner className="size-4" /> {"Analyzing..."}</> }}
                                                {if not explaining { <>{"Explain Risk"}</> }}
                                            </Button>
                                        </div>
                                    </div>
                                    {if view_mode == "graph" { <CallGraph target_fn={target_fn} reports={blast_reports} hop_of={blast_hop_of} /> }}
                                    {if view_mode == "list" { <BlastResultsList reports={blast_reports} hop_of={blast_hop_of} /> }}
                                </div>
                            }}
                        </div>
                    </CardContent>
                </Card>

                {#* Step 3: Explanation *#}
                {if explaining {
                    <Card><CardContent className="flex items-center justify-center pt-12 pb-12">
                        <div className="flex flex-col items-center gap-4">
                            <Spinner className="size-8" />
                            <p className="text-muted-foreground">Analyzing risk with AI... This may take up to 15 seconds.</p>
                        </div>
                    </CardContent></Card>
                }}
                {if explain_error { <Alert><AlertTitle>Explanation Error</AlertTitle><AlertDescription>{explain_error}</AlertDescription></Alert> }}
                {if explanation {
                    <Card>
                        <CardHeader><CardTitle>Risk Analysis</CardTitle><CardDescription>AI-generated assessment of the change impact</CardDescription></CardHeader>
                        <CardContent><div className="prose prose-sm max-w-none text-foreground">{unsafe_html(render_markdown(explanation))}</div></CardContent>
                    </Card>
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
