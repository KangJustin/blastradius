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
        nodes.append({
            "name": fn.name,
            "file": fn.file,
            "source": fn.source[:500] if fn.source else ""
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
