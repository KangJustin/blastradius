"""Unified graph canvas: renders full call graph (mode="full") or blast-radius
radial layout (mode="blast"). Single implementation for rendering, zoom, hover,
click, and tooltips."""

import from .ui.badge { Badge }
import from .ui.button { Button }
import from .ui.card { Card, CardContent }
import from ..lib.utils { cn }

glob _PI: float = 3.14159265358979;

glob _HOP_FILLS: list[str] = [
    "fill-primary", "fill-indigo-400", "fill-indigo-300",
    "fill-violet-400", "fill-purple-400", "fill-fuchsia-400"
];

def _qcurve(x1: float, y1: float, x2: float, y2: float, cxc: float, cyc: float) -> str {
    mx: float = (x1 + x2) / 2.0;
    my: float = (y1 + y2) / 2.0;
    cpx: float = mx + (cxc - mx) * 0.3;
    cpy: float = my + (cyc - my) * 0.3;
    return "M " + str(x1) + " " + str(y1) + " Q " + str(cpx) + " " + str(cpy) + " " + str(x2) + " " + str(y2);
}

def:pub GraphCanvas(
    mode: str,
    graph_nodes: list = [],
    graph_edges: list = [],
    target_fn: str = "",
    reports: list = [],
    hop_of: dict = {},
    on_select: Callable[[str], None] | None = None
) -> JsxElement {
    has selected_fn: str = "";
    has hovered_fn: str = "";
    has zoom: float = 1.0;
    has pan_x: float = 0.0;
    has pan_y: float = 0.0;

    # ---- Layout: compute node positions ----
    positioned: list[dict] = [];
    edges: list[dict] = [];
    base_cx: float = 0.0;
    base_cy: float = 0.0;
    base_w: float = 300.0;
    base_h: float = 300.0;

    if mode == "full" {
        # Circular layout
        count: int = len(graph_nodes);
        if count == 0 {
            return <div className="flex items-center justify-center rounded-lg border bg-card p-8">
                <p className="text-muted-foreground">No functions in the graph. Ingest a repository first.</p>
            </div>;
        }
        padding: float = 50.0;
        radius: float = 40.0 + float(count) * 14.0;
        if radius > 260.0 { radius = 260.0; }
        if radius < 90.0 { radius = 90.0; }
        base_w = (radius + padding) * 2.0;
        base_h = (radius + padding) * 2.0;
        base_cx = base_w / 2.0;
        base_cy = base_h / 2.0;

        for (idx, nd_raw) in enumerate(graph_nodes) {
            nd: dict = nd_raw as dict;
            angle: float = (2.0 * _PI * float(idx)) / float(count);
            nx: float = base_cx + radius * Math.cos(angle - _PI / 2.0);
            ny: float = base_cy + radius * Math.sin(angle - _PI / 2.0);
            positioned = positioned + [{
                "name": str(nd["name"]),
                "file": str(nd["file"]) if nd?["file"] else "",
                "source": str(nd["source"]) if nd?["source"] else "",
                "line": int(nd["line"]) if nd?["line"] else 0,
                "x": nx, "y": ny, "hop": -1, "is_target": False
            }];
        }
        for e_raw in graph_edges {
            e: dict = e_raw as dict;
            edges = edges + [{"from": str(e["caller"]), "to": str(e["callee"])}];
        }
    } else {
        # Blast-radius radial layout
        if len(reports) == 0 {
            return <div className="flex items-center justify-center rounded-lg border bg-card p-8">
                <p className="text-muted-foreground">No blast-radius data.</p>
            </div>;
        }
        max_hop: int = 1;
        for r in reports {
            if r {
                hv = hop_of?[str(r["name"])];
                hi: int = int(hv) if hv else 0;
                if hi > max_hop { max_hop = hi; }
            }
        }
        ring_gap: float = 80.0;
        radius_needed: float = ring_gap * (1.0 + float(max_hop)) + 30.0;
        base_w = radius_needed * 2.0 + 40.0;
        base_h = radius_needed * 2.0 + 40.0;
        if base_w < 300.0 { base_w = 300.0; }
        if base_h < 300.0 { base_h = 300.0; }
        base_cx = base_w / 2.0;
        base_cy = base_h / 2.0;

        hop_groups: dict[int, list] = {};
        for r in reports {
            if not r { continue; }
            fn_name: str = str(r["name"]);
            hop_val = hop_of?[fn_name];
            hop_int: int = int(hop_val) if hop_val else 0;
            if fn_name == target_fn { hop_int = 0; }
            if hop_int not in hop_groups { hop_groups[hop_int] = []; }
            hop_groups[hop_int] = hop_groups[hop_int] + [r];
        }

        # Target at center
        t_src: str = "";
        for r in reports {
            if r and str(r["name"]) == target_fn {
                t_src = str(r["source"]) if r?["source"] else "";
            }
        }
        positioned = positioned + [{"name": target_fn, "x": base_cx, "y": base_cy, "hop": 0, "file": "", "source": t_src, "line": 0, "is_target": True}];

        sorted_hops: list = sorted(hop_groups.keys());
        for hop_key in sorted_hops {
            group: list = hop_groups[hop_key];
            ring_r: float = ring_gap * (1.0 + float(hop_key));
            grp_count: int = len(group);
            for (idx, fn_raw) in enumerate(group) {
                fn_item: dict = fn_raw as dict;
                fn_name: str = str(fn_item["name"]);
                if fn_name == target_fn { continue; }
                angle: float = (2.0 * _PI * float(idx)) / float(grp_count) if grp_count > 0 else 0.0;
                nx: float = base_cx + ring_r * Math.cos(angle);
                ny: float = base_cy + ring_r * Math.sin(angle);
                positioned = positioned + [{"name": fn_name, "x": nx, "y": ny, "hop": int(hop_key),
                    "file": str(fn_item["file"]) if fn_item?["file"] else "",
                    "source": str(fn_item["source"]) if fn_item?["source"] else "",
                    "line": 0, "is_target": False}];
            }
        }
        # Build edges for blast mode
        node_lookup: dict[str, bool] = {};
        for n in positioned { node_lookup[str(n["name"])] = True; }
        for n in positioned {
            if n["is_target"] { continue; }
            hop_v: int = int(n["hop"]);
            if hop_v <= 1 {
                edges = edges + [{"from": target_fn, "to": str(n["name"])}];
            } else {
                added: bool = False;
                for other in positioned {
                    if int(other["hop"]) == hop_v - 1 and str(other["name"]) != target_fn {
                        edges = edges + [{"from": str(other["name"]), "to": str(n["name"])}];
                        added = True;
                        break;
                    }
                }
                if not added { edges = edges + [{"from": target_fn, "to": str(n["name"])}]; }
            }
        }
    }

    # ---- Lookup maps ----
    pos_map: dict[str, dict] = {};
    for p in positioned { pos_map[str(p["name"])] = p; }

    # Caller/callee counts for tooltip
    caller_counts: dict[str, int] = {};
    callee_counts: dict[str, int] = {};
    for p in positioned { caller_counts[str(p["name"])] = 0; callee_counts[str(p["name"])] = 0; }
    all_edges_for_counts: list = edges if mode == "blast" else [];
    if mode == "full" {
        for e_raw in graph_edges {
            e: dict = e_raw as dict;
            cr: str = str(e["caller"]);
            ce: str = str(e["callee"]);
            if cr in callee_counts { callee_counts[cr] = callee_counts[cr] + 1; }
            if ce in caller_counts { caller_counts[ce] = caller_counts[ce] + 1; }
        }
    } else {
        for e in edges {
            cr2: str = str(e["from"]);
            ce2: str = str(e["to"]);
            if cr2 in callee_counts { callee_counts[cr2] = callee_counts[cr2] + 1; }
            if ce2 in caller_counts { caller_counts[ce2] = caller_counts[ce2] + 1; }
        }
    }

    # Hover connected set
    hover_connected: dict[str, bool] = {};
    if hovered_fn or selected_fn {
        focus: str = hovered_fn if hovered_fn else selected_fn;
        hover_connected[focus] = True;
        src_edges: list = edges if mode == "blast" else [];
        if mode == "full" {
            for e_raw in graph_edges {
                e: dict = e_raw as dict;
                if str(e["caller"]) == focus { hover_connected[str(e["callee"])] = True; }
                if str(e["callee"]) == focus { hover_connected[str(e["caller"])] = True; }
            }
        } else {
            for e in edges {
                if str(e["from"]) == focus { hover_connected[str(e["to"])] = True; }
                if str(e["to"]) == focus { hover_connected[str(e["from"])] = True; }
            }
        }
    }

    # ---- Delegated click handler (fixes closure bug) ----
    def handle_svg_click(e: MouseEvent) {
        # Walk up from click target to find data-fn attribute
        node_name: str = "";
        el: any = e.target;
        for _i in range(5) {
            if el and el.getAttribute {
                attr = el.getAttribute("data-fn");
                if attr {
                    node_name = str(attr);
                    break;
                }
                el = el.parentElement as any;
            } else {
                break;
            }
        }
        if node_name {
            selected_fn = node_name;
            if on_select { on_select(node_name); }
        }
    }

    def handle_svg_mouseover(e: MouseEvent) {
        el: any = e.target;
        for _i in range(5) {
            if el and el.getAttribute {
                attr = el.getAttribute("data-fn");
                if attr { hovered_fn = str(attr); return; }
                el = el.parentElement as any;
            } else { break; }
        }
    }

    def handle_svg_mouseout(e: MouseEvent) {
        hovered_fn = "";
    }

    # ---- Zoom controls ----
    def zoom_in(e: MouseEvent) { zoom = zoom * 1.3; }
    def zoom_out(e: MouseEvent) { zoom = zoom / 1.3 if zoom > 0.3 else zoom; }
    def zoom_reset(e: MouseEvent) { zoom = 1.0; pan_x = 0.0; pan_y = 0.0; }
    def zoom_fit(e: MouseEvent) {
        if len(positioned) == 0 { return; }
        min_x: float = 9999.0;
        min_y: float = 9999.0;
        max_x: float = -9999.0;
        max_y: float = -9999.0;
        for n in positioned {
            nx: float = float(n["x"]);
            ny: float = float(n["y"]);
            if nx < min_x { min_x = nx; }
            if ny < min_y { min_y = ny; }
            if nx > max_x { max_x = nx; }
            if ny > max_y { max_y = ny; }
        }
        pad: float = 40.0;
        box_w: float = max_x - min_x + pad * 2.0;
        box_h: float = max_y - min_y + pad * 2.0;
        if box_w < 100.0 { box_w = 100.0; }
        if box_h < 100.0 { box_h = 100.0; }
        zoom = base_w / box_w if base_w / box_w < base_h / box_h else base_h / box_h;
        pan_x = -(min_x - pad) * zoom + (base_w - box_w * zoom) / 2.0;
        pan_y = -(min_y - pad) * zoom + (base_h - box_h * zoom) / 2.0;
    }

    # ViewBox with zoom/pan
    vb_x: float = -pan_x / zoom;
    vb_y: float = -pan_y / zoom;
    vb_w: float = base_w / zoom;
    vb_h: float = base_h / zoom;
    viewbox_str: str = str(vb_x) + " " + str(vb_y) + " " + str(vb_w) + " " + str(vb_h);

    # Selected node for detail
    sel_node: dict | None = None;
    if selected_fn and selected_fn in pos_map { sel_node = pos_map[selected_fn]; }

    # Hovered node for tooltip
    hover_node: dict | None = None;
    if hovered_fn and hovered_fn in pos_map { hover_node = pos_map[hovered_fn]; }

    # Edge source list
    render_edges: list = edges if mode == "blast" else [];

    return <div className="flex flex-col gap-4">
        <div className="relative rounded-lg border bg-card overflow-hidden">
            {#* Zoom controls *#}
            <div className="absolute top-2 left-2 z-10 flex flex-col gap-1">
                <Button size="icon" variant="outline" className="size-7" onClick={zoom_in}><span className="text-xs font-bold">+</span></Button>
                <Button size="icon" variant="outline" className="size-7" onClick={zoom_out}><span className="text-xs font-bold">-</span></Button>
                <Button size="icon" variant="outline" className="size-7" onClick={zoom_fit}><span className="text-[9px] font-bold">Fit</span></Button>
                <Button size="icon" variant="outline" className="size-7" onClick={zoom_reset}><span className="text-[9px]">1:1</span></Button>
            </div>

            {#* Stats overlay *#}
            <div className="absolute top-2 right-2 z-10 flex items-center gap-2">
                <Badge variant="outline">{str(len(positioned)) + " nodes"}</Badge>
                <Badge variant="outline">{str(len(edges) if mode == "blast" else len(graph_edges)) + " edges"}</Badge>
            </div>

            {#* Tooltip *#}
            {if hover_node {
                <div className="absolute bottom-2 left-12 z-10 rounded-md border bg-popover px-3 py-2 text-xs shadow-md max-w-xs">
                    <div className="font-semibold">{str(hover_node["name"])}</div>
                    {if str(hover_node["file"]) {
                        <div className="text-muted-foreground">
                            {str(hover_node["file"]) + (":" + str(hover_node["line"]) if int(hover_node["line"]) > 0 else "")}
                        </div>
                    }}
                    <div className="flex gap-3 mt-1 text-muted-foreground">
                        <span>{"Callers: " + str(caller_counts[str(hover_node["name"])] if str(hover_node["name"]) in caller_counts else 0)}</span>
                        <span>{"Callees: " + str(callee_counts[str(hover_node["name"])] if str(hover_node["name"]) in callee_counts else 0)}</span>
                    </div>
                </div>
            }}

            <svg
                viewBox={viewbox_str}
                className="w-full"
                preserveAspectRatio="xMidYMid meet"
                style={{"height": "400px"}}
                onClick={handle_svg_click}
                onMouseOver={handle_svg_mouseover}
                onMouseOut={handle_svg_mouseout}
            >
                <defs>
                    <marker id="gc-arrow-dim" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto" markerUnits="strokeWidth">
                        <path d="M0,0 L8,3 L0,6 Z" className="fill-muted-foreground/20" />
                    </marker>
                    <marker id="gc-arrow-lit" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto" markerUnits="strokeWidth">
                        <path d="M0,0 L8,3 L0,6 Z" className="fill-primary" />
                    </marker>
                </defs>

                {#* Blast-mode hop rings *#}
                {if mode == "blast" {
                    if len(positioned) > 1 {
                        <circle cx={str(base_cx)} cy={str(base_cy)} r="80" fill="none" className="stroke-border" strokeWidth="1" strokeDasharray="4 4" opacity="0.3" />
                        <circle cx={str(base_cx)} cy={str(base_cy)} r="160" fill="none" className="stroke-border" strokeWidth="1" strokeDasharray="4 4" opacity="0.2" />
                    }
                }}

                {#* Edges *#}
                {if mode == "full" {
                    for (ei, e_raw) in enumerate(graph_edges) {
                        if str((e_raw as dict)["caller"]) in pos_map and str((e_raw as dict)["callee"]) in pos_map {
                            <path key={"e-" + str(ei)}
                                d={_qcurve(float(pos_map[str((e_raw as dict)["caller"])]["x"]), float(pos_map[str((e_raw as dict)["caller"])]["y"]),
                                           float(pos_map[str((e_raw as dict)["callee"])]["x"]), float(pos_map[str((e_raw as dict)["callee"])]["y"]), base_cx, base_cy)}
                                fill="none"
                                className={"stroke-primary transition-all" if ((hovered_fn or selected_fn) and (str((e_raw as dict)["caller"]) == (hovered_fn if hovered_fn else selected_fn) or str((e_raw as dict)["callee"]) == (hovered_fn if hovered_fn else selected_fn))) else "stroke-muted-foreground/15 transition-all"}
                                strokeWidth={"2.5" if ((hovered_fn or selected_fn) and (str((e_raw as dict)["caller"]) == (hovered_fn if hovered_fn else selected_fn) or str((e_raw as dict)["callee"]) == (hovered_fn if hovered_fn else selected_fn))) else "1"}
                                markerEnd={"url(#gc-arrow-lit)" if ((hovered_fn or selected_fn) and (str((e_raw as dict)["caller"]) == (hovered_fn if hovered_fn else selected_fn) or str((e_raw as dict)["callee"]) == (hovered_fn if hovered_fn else selected_fn))) else "url(#gc-arrow-dim)"}
                            />
                        }
                    }}
                }}
                {if mode == "blast" {
                    for (ei, edge) in enumerate(edges) {
                        if str(edge["from"]) in pos_map and str(edge["to"]) in pos_map {
                            <path key={"e-" + str(ei)}
                                d={_qcurve(float(pos_map[str(edge["from"])]["x"]), float(pos_map[str(edge["from"])]["y"]),
                                           float(pos_map[str(edge["to"])]["x"]), float(pos_map[str(edge["to"])]["y"]), base_cx, base_cy)}
                                fill="none"
                                className={"stroke-primary transition-all" if (hovered_fn == str(edge["from"]) or hovered_fn == str(edge["to"])) else "stroke-muted-foreground/20 transition-all"}
                                strokeWidth={"2.5" if (hovered_fn == str(edge["from"]) or hovered_fn == str(edge["to"])) else "1"}
                                markerEnd={"url(#gc-arrow-lit)" if (hovered_fn == str(edge["from"]) or hovered_fn == str(edge["to"])) else "url(#gc-arrow-dim)"}
                            />
                        }
                    }}
                }}

                {#* Nodes — use data-fn for delegated click *#}
                {for (ni, nd) in enumerate(positioned) {
                    <g key={"n-" + str(ni)} data-fn={str(nd["name"])} className="cursor-pointer">
                        {if selected_fn == str(nd["name"]) {
                            <circle cx={str(nd["x"])} cy={str(nd["y"])} r="18" className="fill-primary/10 stroke-primary/30 stroke-1" data-fn={str(nd["name"])} />
                        }}
                        <circle cx={str(nd["x"])} cy={str(nd["y"])} data-fn={str(nd["name"])}
                            r={"12" if (nd["is_target"] if nd?["is_target"] else False) or selected_fn == str(nd["name"]) else ("10" if hovered_fn == str(nd["name"]) else "7")}
                            className={
                                "fill-primary stroke-primary-foreground stroke-2" if ((nd["is_target"] if nd?["is_target"] else False) or selected_fn == str(nd["name"]))
                                else (
                                    "fill-primary/80 stroke-primary stroke-2" if hovered_fn == str(nd["name"])
                                    else (
                                        _HOP_FILLS[int(nd["hop"]) if int(nd["hop"]) >= 0 and int(nd["hop"]) < len(_HOP_FILLS) else 0] + " stroke-background stroke-[1.5]" if (mode == "blast" and int(nd["hop"]) >= 0)
                                        else (
                                            "fill-indigo-400 stroke-background stroke-[1.5]" if ((hovered_fn or selected_fn) and str(nd["name"]) in hover_connected)
                                            else "fill-muted-foreground/40 stroke-background stroke-[1.5]"
                                        )
                                    )
                                )
                            }
                        />
                        {if hovered_fn == str(nd["name"]) or selected_fn == str(nd["name"]) or len(positioned) <= 15 {
                            <text x={str(nd["x"])} y={str(float(nd["y"]) - 16.0)} textAnchor="middle" data-fn={str(nd["name"])}
                                className={"fill-foreground text-[11px] font-semibold" if (hovered_fn == str(nd["name"]) or selected_fn == str(nd["name"])) else "fill-muted-foreground text-[9px]"}
                            >{str(nd["name"])}</text>
                        }}
                    </g>
                }}
            </svg>

            {#* Blast-mode legend *#}
            {if mode == "blast" {
                <div className="absolute bottom-2 right-2 flex items-center gap-3 rounded-md bg-background/80 backdrop-blur-sm border px-3 py-1.5 text-xs">
                    <span className="flex items-center gap-1"><span className="inline-block size-3 rounded-full bg-primary" />{"Target"}</span>
                    <span className="flex items-center gap-1"><span className="inline-block size-3 rounded-full bg-indigo-400" />{"Hop 1"}</span>
                    <span className="flex items-center gap-1"><span className="inline-block size-3 rounded-full bg-indigo-300" />{"Hop 2"}</span>
                </div>
            }}
        </div>

        {#* Selected node detail *#}
        {if sel_node {
            <Card>
                <CardContent className="pt-4 pb-4">
                    <div className="flex items-center justify-between mb-3">
                        <div className="flex items-center gap-2">
                            <span className="text-base font-semibold">{str(sel_node["name"])}</span>
                            {if str(sel_node["file"]) { <Badge variant="outline">{str(sel_node["file"]) + (":" + str(sel_node["line"]) if int(sel_node["line"]) > 0 else "")}</Badge> }}
                            {if mode == "blast" and sel_node?["is_target"] { <Badge variant="secondary">{"Target"}</Badge> }}
                            {if mode == "blast" and not sel_node?["is_target"] and int(sel_node["hop"]) >= 0 { <Badge variant="secondary">{"Hop " + str(sel_node["hop"])}</Badge> }}
                        </div>
                        <button className="text-muted-foreground hover:text-foreground text-sm px-2 py-1 rounded hover:bg-muted"
                            onClick={lambda (e: MouseEvent) { selected_fn = ""; }}>{"Close"}</button>
                    </div>
                    <div className="flex gap-4 mb-3 text-sm text-muted-foreground">
                        <span>{"Callers: " + str(caller_counts[str(sel_node["name"])] if str(sel_node["name"]) in caller_counts else 0)}</span>
                        <span>{"Callees: " + str(callee_counts[str(sel_node["name"])] if str(sel_node["name"]) in callee_counts else 0)}</span>
                    </div>
                    {if str(sel_node["source"]) {
                        <div className="rounded-md bg-muted/50 border overflow-x-auto">
                            <pre className="p-3 text-xs font-mono leading-relaxed text-foreground whitespace-pre-wrap"><code>{str(sel_node["source"])}</code></pre>
                        </div>
                    }}
                </CardContent>
            </Card>
        }}
    </div>;
}
