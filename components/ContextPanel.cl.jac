"""Context panel: shows selected function details pre-analysis, and blast-radius
results + suggested tests post-analysis. Fires suggest_tests in parallel."""

import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.button { Button }
import from .ui.input { Input }
import from .ui.badge { Badge }
import from .ui.spinner { Spinner }
import from .ui.alert { Alert, AlertTitle, AlertDescription }
import from ..lib.utils { cn }

def:pub ContextPanel(
    target_fn: str,
    full_graph: dict | None,
    blast_done: bool,
    blast_found: bool,
    blast_reports: list,
    blast_hop_of: dict,
    blast_error: str,
    computing: bool,
    max_hops: int,
    on_hops_change: Callable[[str], None],
    on_analyze: Callable[[], None],
    # Reveal animation state
    revealed_hops: int,
    # Suggest tests
    suggested_tests: list,
    tests_loading: bool
) -> JsxElement {
    if not target_fn {
        return <></>;
    }

    # --- Derive callers/callees from full_graph edges ---
    callers: list[str] = [];
    callees: list[str] = [];
    fn_file: str = "";
    fn_source: str = "";
    fn_line: int = 0;
    if full_graph {
        nodes_list: list = full_graph["nodes"] as list;
        edges_list: list = full_graph["edges"] as list;
        for nd_raw in nodes_list {
            nd: dict = nd_raw as dict;
            if str(nd["name"]) == target_fn {
                fn_file = str(nd["file"]) if nd?["file"] else "";
                fn_source = str(nd["source"]) if nd?["source"] else "";
                fn_line = int(nd["line"]) if nd?["line"] else 0;
            }
        }
        for e_raw in edges_list {
            e: dict = e_raw as dict;
            if str(e["callee"]) == target_fn {
                callers = callers + [str(e["caller"])];
            }
            if str(e["caller"]) == target_fn {
                callees = callees + [str(e["callee"])];
            }
        }
    }

    # Max hop reached from blast results
    max_hop_reached: int = 0;
    if blast_done and blast_found {
        for k_raw in blast_hop_of.keys() {
            v = blast_hop_of[k_raw];
            hv: int = int(v) if v else 0;
            if hv > max_hop_reached { max_hop_reached = hv; }
        }
    }

    def handle_hops_input(e: ChangeEvent) {
        on_hops_change(e.target.value);
    }

    return <Card>
        <CardHeader>
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                    <CardTitle className="font-mono text-base">{target_fn}</CardTitle>
                    {if fn_file {
                        <Badge variant="outline">{fn_file + (":" + str(fn_line) if fn_line > 0 else "")}</Badge>
                    }}
                </div>
                {if blast_done and blast_found {
                    <Badge variant="secondary">{"Pending severity"}</Badge>
                }}
            </div>
        </CardHeader>
        <CardContent>
            <div className="flex flex-col gap-4">
                {#* Callers / Callees *#}
                {if len(callers) > 0 or len(callees) > 0 {
                    <div className="flex flex-wrap gap-4 text-sm">
                        {if len(callers) > 0 {
                            <div className="flex items-center gap-1.5">
                                <span className="text-muted-foreground">{"Called by:"}</span>
                                {for c in callers {
                                    <Badge key={c} variant="secondary" className="text-xs font-mono">{c}</Badge>
                                }}
                            </div>
                        }}
                        {if len(callees) > 0 {
                            <div className="flex items-center gap-1.5">
                                <span className="text-muted-foreground">{"Calls:"}</span>
                                {for c in callees {
                                    <Badge key={c} variant="secondary" className="text-xs font-mono">{c}</Badge>
                                }}
                            </div>
                        }}
                    </div>
                }}

                {#* Source preview (pre-analysis) *#}
                {if fn_source and not blast_done {
                    <div className="rounded-md bg-muted/50 border overflow-x-auto">
                        <pre className="p-3 text-xs font-mono leading-relaxed text-foreground whitespace-pre-wrap"><code>{fn_source}</code></pre>
                    </div>
                }}

                {#* Analyze controls (pre-analysis) *#}
                {if not blast_done and not computing {
                    <div className="flex items-center gap-2 pt-2">
                        <span className="text-sm text-muted-foreground">{"Max hops:"}</span>
                        <Input type="number" value={str(max_hops)} onChange={handle_hops_input} className="w-20" />
                        <Button onClick={lambda (e: MouseEvent) { on_analyze(); }} disabled={not target_fn}>
                            {"Analyze blast radius"}
                        </Button>
                    </div>
                }}

                {#* Computing state *#}
                {if computing {
                    <div className="flex items-center gap-2 py-2">
                        <Spinner className="size-4" />
                        <span className="text-sm text-muted-foreground">{"Computing blast radius..."}</span>
                    </div>
                }}

                {#* Error *#}
                {if blast_error {
                    <Alert><AlertTitle>Error</AlertTitle><AlertDescription>{blast_error}</AlertDescription></Alert>
                }}

                {#* Post-analysis results *#}
                {if blast_done and blast_found {
                    <div className="flex flex-col gap-3">
                        <div className="flex items-center gap-4 text-sm">
                            <div className="flex items-center gap-1.5">
                                <span className="text-muted-foreground">{"Affected:"}</span>
                                <span className="font-semibold tabular-nums">{str(len(blast_reports))}</span>
                            </div>
                            <div className="flex items-center gap-1.5">
                                <span className="text-muted-foreground">{"Max hop:"}</span>
                                <span className="font-semibold tabular-nums">{str(max_hop_reached)}</span>
                            </div>
                            <div className="flex items-center gap-1.5">
                                <span className="text-muted-foreground">{"Revealed:"}</span>
                                <span className="font-semibold tabular-nums">{"hop " + str(revealed_hops)}</span>
                            </div>
                        </div>

                        {#* Suggested tests *#}
                        {if tests_loading {
                            <div className="flex items-center gap-2 text-sm text-muted-foreground">
                                <Spinner className="size-3.5" />
                                {"Finding test files..."}
                            </div>
                        }}
                        {if len(suggested_tests) > 0 {
                            <div className="flex flex-col gap-1">
                                <span className="text-sm text-muted-foreground">{"Suggested test files:"}</span>
                                <div className="flex flex-wrap gap-1.5">
                                    {for t in suggested_tests {
                                        <Badge key={t} variant="outline" className="text-xs font-mono">{t}</Badge>
                                    }}
                                </div>
                            </div>
                        }}
                    </div>
                }}

                {if blast_done and not blast_found {
                    <Alert>
                        <AlertTitle>Function not found</AlertTitle>
                        <AlertDescription>{"\"" + target_fn + "\" was not found in the ingested graph."}</AlertDescription>
                    </Alert>
                }}
            </div>
        </CardContent>
    </Card>;
}
