"""RiskReport: renders the AI-generated risk explanation as a structured report
with severity badge, scannable sections, and clear data-source labels."""

import from .ui.card { Card, CardHeader, CardTitle, CardContent }
import from .ui.badge { Badge }
import from .ui.spinner { Spinner }
import from .ui.alert { Alert, AlertTitle, AlertDescription }
import from ..lib.utils { cn }

def:pub RiskReport(
    target_fn: str,
    affected: list,
    on_request_explain: Callable[[], None] | None = None
) -> JsxElement {
    has risk_data: dict | None = None;
    has loading: bool = False;
    has error_msg: str = "";
    has expanded: bool = False;

    async def fetch_risk() -> None {
        if not target_fn or len(affected) == 0 { return; }
        loading = True;
        error_msg = "";
        risk_data = None;
        affected_names: list[str] = [];
        for r in affected {
            if r { affected_names = affected_names + [str(r["name"])]; }
        }
        resp = await fetch("/function/explain_risk", {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify({"target": target_fn, "affected": affected_names})
        });
        if not resp.ok {
            body = await resp.text();
            error_msg = "Risk analysis failed (" + str(resp.status) + "): " + body;
            loading = False;
            return;
        }
        raw = await resp.text();
        parsed = JSON.parse(raw);
        result = parsed["data"]["result"];
        if result {
            risk_data = {
                "summary": str(result["summary"]) if result["summary"] else "",
                "why_risky": str(result["why_risky"]) if result["why_risky"] else "",
                "could_break": str(result["could_break"]) if result["could_break"] else "",
                "severity": str(result["severity"]) if result["severity"] else "medium"
            };
        }
        loading = False;
    }

    # No function selected
    if not target_fn {
        return <Card>
            <CardContent className="pt-6 pb-6">
                <p className="text-sm text-muted-foreground text-center">Select a function to generate a risk assessment.</p>
            </CardContent>
        </Card>;
    }

    # Not yet requested
    if not loading and not risk_data and not error_msg {
        return <Card>
            <CardHeader>
                <div className="flex items-center justify-between">
                    <CardTitle>Risk Analysis</CardTitle>
                    <Badge variant="outline" className="text-xs">AI-generated explanation</Badge>
                </div>
            </CardHeader>
            <CardContent>
                <button
                    className="w-full rounded-md border border-dashed px-4 py-3 text-sm text-muted-foreground hover:text-foreground hover:border-primary transition-colors"
                    onClick={lambda (e: MouseEvent) { fetch_risk(); }}
                >
                    {"Generate risk assessment for " + target_fn}
                </button>
            </CardContent>
        </Card>;
    }

    # Loading
    if loading {
        return <Card>
            <CardHeader>
                <div className="flex items-center justify-between">
                    <CardTitle>Risk Analysis</CardTitle>
                    <Badge variant="outline" className="text-xs">AI-generated explanation</Badge>
                </div>
            </CardHeader>
            <CardContent>
                <div className="flex items-center gap-3 py-4">
                    <Spinner className="size-5" />
                    <div className="flex flex-col gap-1">
                        <span className="text-sm font-medium">Analyzing risk...</span>
                        <span className="text-xs text-muted-foreground">This may take 5-15 seconds (live LLM call)</span>
                    </div>
                </div>
                {#* Skeleton sections *#}
                <div className="flex flex-col gap-3 mt-4">
                    <div className="h-4 w-24 rounded bg-muted animate-pulse" />
                    <div className="h-3 w-full rounded bg-muted animate-pulse" />
                    <div className="h-3 w-3/4 rounded bg-muted animate-pulse" />
                    <div className="h-4 w-32 rounded bg-muted animate-pulse mt-2" />
                    <div className="h-3 w-full rounded bg-muted animate-pulse" />
                </div>
            </CardContent>
        </Card>;
    }

    # Error
    if error_msg {
        return <Card>
            <CardHeader>
                <div className="flex items-center justify-between">
                    <CardTitle>Risk Analysis</CardTitle>
                    <Badge variant="outline" className="text-xs">AI-generated explanation</Badge>
                </div>
            </CardHeader>
            <CardContent>
                <Alert>
                    <AlertTitle>Analysis failed</AlertTitle>
                    <AlertDescription>{error_msg}</AlertDescription>
                </Alert>
                <button
                    className="mt-3 text-sm text-primary hover:underline"
                    onClick={lambda (e: MouseEvent) { fetch_risk(); }}
                >
                    {"Retry"}
                </button>
            </CardContent>
        </Card>;
    }

    # Success — render structured report
    if not risk_data { return <></>; }

    sev: str = str(risk_data["severity"]);
    sev_color: str = "bg-yellow-500/10 text-yellow-700 border-yellow-500/30" if sev == "medium" else (
        "bg-red-500/10 text-red-700 border-red-500/30" if sev == "high" else "bg-emerald-500/10 text-emerald-700 border-emerald-500/30"
    );

    return <Card>
        <CardHeader>
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                    <CardTitle>Risk Analysis</CardTitle>
                    <span className={cn("inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold uppercase tracking-wider", sev_color)}>
                        {sev}
                    </span>
                </div>
                <Badge variant="outline" className="text-xs">AI-generated explanation</Badge>
            </div>
        </CardHeader>
        <CardContent>
            <div className="flex flex-col gap-4">
                {#* Summary *#}
                <div className="flex flex-col gap-1">
                    <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Summary</span>
                    <p className="text-sm leading-relaxed">{str(risk_data["summary"])}</p>
                </div>

                {#* Why risky *#}
                <div className="flex flex-col gap-1">
                    <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Why it is risky</span>
                    <p className="text-sm leading-relaxed">{str(risk_data["why_risky"])}</p>
                </div>

                {#* Could break *#}
                <div className="flex flex-col gap-1">
                    <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">What could break</span>
                    <p className="text-sm leading-relaxed">{str(risk_data["could_break"])}</p>
                </div>

                {#* Collapsed detailed explanation *#}
                <div className="border-t pt-3">
                    <button
                        className="text-sm text-muted-foreground hover:text-foreground flex items-center gap-1"
                        onClick={lambda (e: MouseEvent) { expanded = not expanded; }}
                    >
                        <span className={cn("transition-transform", "rotate-90" if expanded else "")}>{">"}</span>
                        {"Detailed explanation"}
                    </button>
                    {if expanded {
                        <div className="mt-2 rounded-md bg-muted/30 p-3 text-sm leading-relaxed">
                            <p>{str(risk_data["summary"]) + " " + str(risk_data["why_risky"]) + " " + str(risk_data["could_break"])}</p>
                        </div>
                    }}
                </div>

                {#* Data source labels *#}
                <div className="border-t pt-3 flex flex-col gap-1 text-xs text-muted-foreground">
                    <div className="flex items-center gap-1.5">
                        <span className="inline-block size-1.5 rounded-full bg-emerald-500" />
                        {"Suggested tests and affected functions: Computed from graph traversal"}
                    </div>
                    <div className="flex items-center gap-1.5">
                        <span className="inline-block size-1.5 rounded-full bg-indigo-500" />
                        {"Summary, risk assessment, severity: AI-generated explanation"}
                    </div>
                </div>
            </div>
        </CardContent>
    </Card>;
}
