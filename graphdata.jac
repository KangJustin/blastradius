"""Returns the full ingested call graph: all Function nodes and Calls edges."""

import from graph { Function, Calls }

obj GraphData {
    has nodes: list[dict];
    has edges: list[dict];
}

def:pub get_graph() -> GraphData {
    all_fns: list = [root -->][?:Function];
    nodes: list[dict] = [];
    edges: list[dict] = [];

    for fn in all_fns {
        # Extract first line number from source (def foo at line N)
        line_num: int = 0;
        if fn.source {
            # Count newlines before first 'def ' to approximate line
            idx = fn.source.find("def ");
            if idx >= 0 {
                line_num = fn.source[:idx].count("\n") as int + 1;
            }
        }
        nodes.append({
            "name": fn.name,
            "file": fn.file,
            "source": fn.source[:500] if fn.source else "",
            "line": line_num
        });
        # Outgoing call edges
        for callee in [fn ->:Calls:->] {
            edges.append({
                "caller": fn.name,
                "callee": callee.name
            });
        }
    }

    return GraphData(nodes=nodes, edges=edges);
}
