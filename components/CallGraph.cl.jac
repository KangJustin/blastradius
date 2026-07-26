"""Interactive SVG call-graph visualization.
Renders the target function at center with affected functions in concentric rings by hop distance.
Nodes are clickable to show details; edges connect caller/callee pairs."""

import from .ui.badge { Badge }
import from .ui.card { Card, CardContent }
import from ..lib.utils { cn }

glob _PI: float = 3.14159265358979;

def _curve(x1: float, y1: float, x2: float, y2: float, cxc: float, cyc: float) -> str {
    mx: float = (x1 + x2) / 2.0;
    my: float = (y1 + y2) / 2.0;
    cpx: float = mx + (cxc - mx) * 0.3;
    cpy: float = my + (cyc - my) * 0.3;
    return "M " + str(x1) + " " + str(y1) + " Q " + str(cpx) + " " + str(cpy) + " " + str(x2) + " " + str(y2);
}

glob _HOP_COLORS: list[str] = [
    "fill-primary",
    "fill-indigo-400",
    "fill-indigo-300",
    "fill-violet-400",
    "fill-purple-400",
    "fill-fuchsia-400"
];

def:pub CallGraph(
    target_fn: str,
    reports: list,
    hop_of: dict,
    on_select: Callable[[str], None] | None = None
) -> JsxElement {
    has selected_fn: str = "";
    has hovered_fn: str = "";

    max_hop: int = 1;
    for r in reports {
        if r {
            hv = hop_of?[str(r["name"])];
            hi: int = int(hv) if hv else 0;
            if hi > max_hop { max_hop = hi; }
        }
    }
    ring_gap: float = 80.0;
    node_r: float = 8.0;
    radius_needed: float = ring_gap * (1.0 + float(max_hop)) + 30.0;
    vw: float = radius_needed * 2.0 + 40.0;
    vh: float = radius_needed * 2.0 + 40.0;
    if vw < 300.0 { vw = 300.0; }
    if vh < 300.0 { vh = 300.0; }
    cx: float = vw / 2.0;
    cy: float = vh / 2.0;

    nodes: list[dict] = [];
    edges: list[dict] = [];

    hop_groups: dict[int, list] = {};
    for r in reports {
        if not r { continue; }
        fn_name: str = str(r["name"]);
        hop_val = hop_of?[fn_name];
        hop_int: int = int(hop_val) if hop_val else 0;
        if fn_name == target_fn { hop_int = 0; }
        if hop_int not in hop_groups {
            hop_groups[hop_int] = [];
        }
        hop_groups[hop_int] = hop_groups[hop_int] + [r];
    }

    target_source: str = "";
    for r in reports {
        if r and str(r["name"]) == target_fn {
            target_source = str(r["source"]) if r?["source"] else "";
        }
    }
    nodes = nodes + [{"name": target_fn, "x": cx, "y": cy, "hop": 0, "file": "", "source": target_source, "is_target": True}];

    sorted_hops: list = sorted(hop_groups.keys());
    for hop_key in sorted_hops {
        group: list = hop_groups[hop_key];
        ring_r: float = ring_gap * (1.0 + float(hop_key));
        count: int = len(group);
        for (idx, fn_item_raw) in enumerate(group) {
            fn_item: dict = fn_item_raw as dict;
            fn_name: str = str(fn_item["name"]);
            if fn_name == target_fn { continue; }
            angle: float = (2.0 * _PI * float(idx)) / float(count) if count > 0 else 0.0;
            nx: float = cx + ring_r * Math.cos(angle);
            ny: float = cy + ring_r * Math.sin(angle);
            file_str: str = str(fn_item["file"]) if fn_item?["file"] else "";
            src_str: str = str(fn_item["source"]) if fn_item?["source"] else "";
            nodes = nodes + [{"name": fn_name, "x": nx, "y": ny, "hop": int(hop_key), "file": file_str, "source": src_str, "is_target": False}];
        }
    }

    node_map: dict[str, dict] = {};
    for n in nodes {
        node_map[str(n["name"])] = n;
    }
    for n in nodes {
        if n["is_target"] { continue; }
        hop_val_int: int = int(n["hop"]);
        if hop_val_int <= 1 {
            edges = edges + [{"from": target_fn, "to": str(n["name"])}];
        } else {
            for other in nodes {
                if int(other["hop"]) == hop_val_int - 1 and str(other["name"]) != target_fn {
                    edges = edges + [{"from": str(other["name"]), "to": str(n["name"])}];
                    break;
                }
            }
            found_edge: bool = False;
            for e in edges {
                if str(e["to"]) == str(n["name"]) { found_edge = True; }
            }
            if not found_edge {
                edges = edges + [{"from": target_fn, "to": str(n["name"])}];
            }
        }
    }

    def handle_node_click(fn_name: str) {
        selected_fn = fn_name;
        if on_select { on_select(fn_name); }
    }

    selected_node: dict | None = None;
    if selected_fn {
        for n in nodes {
            if str(n["name"]) == selected_fn { selected_node = n; }
        }
    }

    return <div className="flex flex-col gap-4">
        <div className="relative rounded-lg border bg-card overflow-hidden">
            <svg viewBox={"0 0 " + str(vw) + " " + str(vh)} className="w-full" preserveAspectRatio="xMidYMid meet" style={{"height": "380px"}}>
                <defs>
                    <marker id="br-arrow-dim" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto" markerUnits="strokeWidth">
                        <path d="M0,0 L8,3 L0,6 Z" className="fill-muted-foreground/20" />
                    </marker>
                    <marker id="br-arrow-lit" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto" markerUnits="strokeWidth">
                        <path d="M0,0 L8,3 L0,6 Z" className="fill-primary" />
                    </marker>
                </defs>
                {for hop_idx in sorted_hops {
                    <circle key={"ring-" + str(hop_idx)} cx={str(cx)} cy={str(cy)} r={str(ring_gap * (1.0 + float(hop_idx)))} fill="none" className="stroke-border" strokeWidth="1" strokeDasharray="4 4" opacity="0.3" />
                }}
                {for (ei, edge) in enumerate(edges) {
                    if str(edge["from"]) in node_map and str(edge["to"]) in node_map {
                        <path key={"edge-" + str(ei)}
                            d={_curve(float(node_map[str(edge["from"])]["x"]), float(node_map[str(edge["from"])]["y"]), float(node_map[str(edge["to"])]["x"]), float(node_map[str(edge["to"])]["y"]), cx, cy)}
                            fill="none"
                            className={"stroke-primary transition-all" if (hovered_fn == str(edge["from"]) or hovered_fn == str(edge["to"])) else "stroke-muted-foreground/20 transition-all"}
                            strokeWidth={"2.5" if (hovered_fn == str(edge["from"]) or hovered_fn == str(edge["to"])) else "1"}
                            markerEnd={"url(#br-arrow-lit)" if (hovered_fn == str(edge["from"]) or hovered_fn == str(edge["to"])) else "url(#br-arrow-dim)"}
                        />
                    }
                }}
                {for (ni, node) in enumerate(nodes) {
                    <g key={"node-" + str(ni)} className="cursor-pointer"
                        onClick={lambda { handle_node_click(str(node["name"])); }}
                        onMouseEnter={lambda { hovered_fn = str(node["name"]); }}
                        onMouseLeave={lambda { hovered_fn = ""; }}
                    >
                        <circle cx={str(node["x"])} cy={str(node["y"])}
                            r={str(14.0 if node["is_target"] else (10.0 if hovered_fn == str(node["name"]) or selected_fn == str(node["name"]) else node_r))}
                            className={
                                "fill-primary stroke-primary-foreground stroke-2" if node["is_target"]
                                else ("fill-primary/80 stroke-primary stroke-2" if selected_fn == str(node["name"])
                                else (_HOP_COLORS[int(node["hop"]) if int(node["hop"]) < len(_HOP_COLORS) else len(_HOP_COLORS) - 1] + " stroke-background stroke-2"))
                            }
                        />
                        <text x={str(node["x"])} y={str(float(node["y"]) - 18.0)} textAnchor="middle"
                            className={"fill-foreground text-[11px] font-semibold" if (node["is_target"] or hovered_fn == str(node["name"]) or selected_fn == str(node["name"])) else "fill-muted-foreground text-[10px]"}
                        >{str(node["name"])}</text>
                    </g>
                }}
            </svg>
            <div className="absolute bottom-2 left-2 flex items-center gap-3 rounded-md bg-background/80 backdrop-blur-sm border px-3 py-1.5 text-xs">
                <span className="flex items-center gap-1"><span className="inline-block size-3 rounded-full bg-primary" />{"Target"}</span>
                <span className="flex items-center gap-1"><span className="inline-block size-3 rounded-full bg-indigo-400" />{"Hop 1"}</span>
                <span className="flex items-center gap-1"><span className="inline-block size-3 rounded-full bg-indigo-300" />{"Hop 2"}</span>
                <span className="flex items-center gap-1"><span className="inline-block size-3 rounded-full bg-violet-400" />{"Hop 3+"}</span>
            </div>
        </div>
        {if selected_node {
            <Card>
                <CardContent className="pt-4 pb-4">
                    <div className="flex items-center justify-between mb-3">
                        <div className="flex items-center gap-2">
                            <span className="text-base font-semibold">{str(selected_node["name"])}</span>
                            <Badge variant="outline">{"Target" if selected_node["is_target"] else "Hop " + str(selected_node["hop"])}</Badge>
                            {if str(selected_node["file"]) { <Badge variant="secondary">{str(selected_node["file"])}</Badge> }}
                        </div>
                        <button className="text-muted-foreground hover:text-foreground text-sm px-2 py-1 rounded hover:bg-muted" onClick={lambda (e: MouseEvent) { selected_fn = ""; }}>{"Close"}</button>
                    </div>
                    {if str(selected_node?["source"]) {
                        <div className="rounded-md bg-muted/50 border overflow-x-auto">
                            <pre className="p-3 text-xs font-mono leading-relaxed text-foreground whitespace-pre-wrap"><code>{str(selected_node["source"])}</code></pre>
                        </div>
                    }}
                </CardContent>
            </Card>
        }}
    </div>;
}
