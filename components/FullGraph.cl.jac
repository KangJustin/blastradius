"""Full call-graph visualization showing all ingested functions and their call edges.
Circular layout with curved directed edges, clickable nodes with source preview, and hover tooltips."""

import from .ui.badge { Badge }
import from .ui.card { Card, CardContent }
import from ..lib.utils { cn }

glob _PI: float = 3.14159265358979;

def curve_path(x1: float, y1: float, x2: float, y2: float, cxc: float, cyc: float) -> str {
    mx: float = (x1 + x2) / 2.0;
    my: float = (y1 + y2) / 2.0;
    cpx: float = mx + (cxc - mx) * 0.3;
    cpy: float = my + (cyc - my) * 0.3;
    return "M " + str(x1) + " " + str(y1) + " Q " + str(cpx) + " " + str(cpy) + " " + str(x2) + " " + str(y2);
}

def:pub FullGraph(
    graph_nodes: list,
    graph_edges: list,
    on_select_fn: Callable[[str], None] | None = None
) -> JsxElement {
    has selected_fn: str = "";
    has hovered_fn: str = "";

    count: int = len(graph_nodes);
    if count == 0 {
        return <div className="flex items-center justify-center rounded-lg border bg-card p-8">
            <p className="text-muted-foreground">No functions in the graph. Ingest a repository first.</p>
        </div>;
    }

    # Layout: circular arrangement
    padding: float = 50.0;
    radius: float = 40.0 + float(count) * 14.0;
    if radius > 260.0 { radius = 260.0; }
    if radius < 90.0 { radius = 90.0; }
    vw: float = (radius + padding) * 2.0;
    vh: float = (radius + padding) * 2.0;
    cx: float = vw / 2.0;
    cy: float = vh / 2.0;

    # Position nodes in a circle
    positioned: list[dict] = [];
    for (idx, nd_raw) in enumerate(graph_nodes) {
        nd: dict = nd_raw as dict;
        angle: float = (2.0 * _PI * float(idx)) / float(count);
        nx: float = cx + radius * Math.cos(angle - _PI / 2.0);
        ny: float = cy + radius * Math.sin(angle - _PI / 2.0);
        positioned = positioned + [{
            "name": str(nd["name"]),
            "file": str(nd["file"]) if nd?["file"] else "",
            "source": str(nd["source"]) if nd?["source"] else "",
            "x": nx,
            "y": ny
        }];
    }

    # Build lookup
    pos_map: dict[str, dict] = {};
    for p in positioned {
        pos_map[str(p["name"])] = p;
    }

    # Connected set for hovered node
    hover_connected: dict[str, bool] = {};
    callers_of_selected: list[str] = [];
    callees_of_selected: list[str] = [];
    if hovered_fn or selected_fn {
        focus_fn: str = hovered_fn if hovered_fn else selected_fn;
        hover_connected[focus_fn] = True;
        for e_raw in graph_edges {
            e: dict = e_raw as dict;
            if str(e["caller"]) == focus_fn {
                hover_connected[str(e["callee"])] = True;
                if focus_fn == selected_fn { callees_of_selected = callees_of_selected + [str(e["callee"])]; }
            }
            if str(e["callee"]) == focus_fn {
                hover_connected[str(e["caller"])] = True;
                if focus_fn == selected_fn { callers_of_selected = callers_of_selected + [str(e["caller"])]; }
            }
        }
    }

    def handle_click(fn_name: str) {
        selected_fn = fn_name if selected_fn != fn_name else "";
        if on_select_fn and selected_fn { on_select_fn(fn_name); }
    }

    # Selected node info
    sel_node: dict | None = None;
    if selected_fn and selected_fn in pos_map {
        sel_node = pos_map[selected_fn];
    }

    return <div className="flex flex-col gap-4">
        <div className="relative rounded-lg border bg-card overflow-hidden">
            <svg
                viewBox={"0 0 " + str(vw) + " " + str(vh)}
                className="w-full"
                preserveAspectRatio="xMidYMid meet"
                style={{"height": "400px"}}
            >
                <defs>
                    <marker id="arrow-dim" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto" markerUnits="strokeWidth">
                        <path d="M0,0 L8,3 L0,6 Z" className="fill-muted-foreground/20" />
                    </marker>
                    <marker id="arrow-lit" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto" markerUnits="strokeWidth">
                        <path d="M0,0 L8,3 L0,6 Z" className="fill-primary" />
                    </marker>
                </defs>

                {#* Edges as curved paths *#}
                {for (ei, e_raw) in enumerate(graph_edges) {
                    if str((e_raw as dict)["caller"]) in pos_map and str((e_raw as dict)["callee"]) in pos_map {
                        <path
                            key={"e-" + str(ei)}
                            d={curve_path(
                                float(pos_map[str((e_raw as dict)["caller"])]["x"]),
                                float(pos_map[str((e_raw as dict)["caller"])]["y"]),
                                float(pos_map[str((e_raw as dict)["callee"])]["x"]),
                                float(pos_map[str((e_raw as dict)["callee"])]["y"]),
                                cx, cy
                            )}
                            fill="none"
                            className={
                                "stroke-primary transition-all" if (
                                    (hovered_fn or selected_fn) and (
                                        str((e_raw as dict)["caller"]) == (hovered_fn if hovered_fn else selected_fn)
                                        or str((e_raw as dict)["callee"]) == (hovered_fn if hovered_fn else selected_fn)
                                    )
                                ) else "stroke-muted-foreground/15 transition-all"
                            }
                            strokeWidth={
                                "2.5" if (
                                    (hovered_fn or selected_fn) and (
                                        str((e_raw as dict)["caller"]) == (hovered_fn if hovered_fn else selected_fn)
                                        or str((e_raw as dict)["callee"]) == (hovered_fn if hovered_fn else selected_fn)
                                    )
                                ) else "1"
                            }
                            markerEnd={
                                "url(#arrow-lit)" if (
                                    (hovered_fn or selected_fn) and (
                                        str((e_raw as dict)["caller"]) == (hovered_fn if hovered_fn else selected_fn)
                                        or str((e_raw as dict)["callee"]) == (hovered_fn if hovered_fn else selected_fn)
                                    )
                                ) else "url(#arrow-dim)"
                            }
                        />
                    }
                }}

                {#* Nodes *#}
                {for (ni, nd) in enumerate(positioned) {
                    <g
                        key={"n-" + str(ni)}
                        className="cursor-pointer"
                        onClick={lambda { handle_click(str(nd["name"])); }}
                        onMouseEnter={lambda { hovered_fn = str(nd["name"]); }}
                        onMouseLeave={lambda { hovered_fn = ""; }}
                    >
                        {if selected_fn == str(nd["name"]) {
                            <circle cx={str(nd["x"])} cy={str(nd["y"])} r="18" className="fill-primary/10 stroke-primary/30 stroke-1" />
                        }}
                        <circle
                            cx={str(nd["x"])}
                            cy={str(nd["y"])}
                            r={"12" if selected_fn == str(nd["name"]) else ("10" if hovered_fn == str(nd["name"]) else "7")}
                            className={
                                "fill-primary stroke-primary-foreground stroke-2" if selected_fn == str(nd["name"])
                                else (
                                    "fill-primary/80 stroke-primary stroke-2" if hovered_fn == str(nd["name"])
                                    else (
                                        "fill-indigo-400 stroke-background stroke-[1.5]" if ((hovered_fn or selected_fn) and str(nd["name"]) in hover_connected)
                                        else "fill-muted-foreground/40 stroke-background stroke-[1.5]"
                                    )
                                )
                            }
                        />
                        {if hovered_fn == str(nd["name"]) or selected_fn == str(nd["name"]) or count <= 15 {
                            <text
                                x={str(nd["x"])}
                                y={str(float(nd["y"]) - 16.0)}
                                textAnchor="middle"
                                className={
                                    "fill-foreground text-[11px] font-semibold" if (hovered_fn == str(nd["name"]) or selected_fn == str(nd["name"]))
                                    else "fill-muted-foreground text-[9px]"
                                }
                            >
                                {str(nd["name"])}
                            </text>
                        }}
                    </g>
                }}
            </svg>

            <div className="absolute top-2 right-2 flex items-center gap-2">
                <Badge variant="outline">{str(count) + " functions"}</Badge>
                <Badge variant="outline">{str(len(graph_edges)) + " calls"}</Badge>
            </div>
        </div>

        {if sel_node {
            <Card>
                <CardContent className="pt-4 pb-4">
                    <div className="flex items-center justify-between mb-3">
                        <div className="flex items-center gap-2">
                            <span className="text-base font-semibold">{str(sel_node["name"])}</span>
                            {if str(sel_node["file"]) {
                                <Badge variant="outline">{str(sel_node["file"])}</Badge>
                            }}
                        </div>
                        <button
                            className="text-muted-foreground hover:text-foreground text-sm px-2 py-1 rounded hover:bg-muted"
                            onClick={lambda (e: MouseEvent) { selected_fn = ""; }}
                        >
                            {"Close"}
                        </button>
                    </div>
                    {if len(callers_of_selected) > 0 or len(callees_of_selected) > 0 {
                        <div className="flex flex-wrap gap-4 mb-3 text-sm">
                            {if len(callers_of_selected) > 0 {
                                <div className="flex items-center gap-1">
                                    <span className="text-muted-foreground">{"Called by:"}</span>
                                    {for c in callers_of_selected {
                                        <Badge key={c} variant="secondary" className="text-xs">{c}</Badge>
                                    }}
                                </div>
                            }}
                            {if len(callees_of_selected) > 0 {
                                <div className="flex items-center gap-1">
                                    <span className="text-muted-foreground">{"Calls:"}</span>
                                    {for c in callees_of_selected {
                                        <Badge key={c} variant="secondary" className="text-xs">{c}</Badge>
                                    }}
                                </div>
                            }}
                        </div>
                    }}
                    {if str(sel_node["source"]) {
                        <div className="rounded-md bg-muted/50 border overflow-x-auto">
                            <pre className="p-3 text-xs font-mono leading-relaxed text-foreground whitespace-pre-wrap">
                                <code>{str(sel_node["source"])}</code>
                            </pre>
                        </div>
                    }}
                    {if not str(sel_node["source"]) {
                        <p className="text-sm text-muted-foreground italic">{"No source available."}</p>
                    }}
                </CardContent>
            </Card>
        }}
    </div>;
}
