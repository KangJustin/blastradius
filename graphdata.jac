"""Read-only endpoint that returns the full ingested graph (files, functions,
call edges) as plain JSON, so a frontend can render an actual node-link
diagram instead of only printing traversal results as text.
"""

import from graph { File, Function, Calls }

def:pub get_graph() -> dict {
    fn_nodes: list[dict] = [];
    for fn in [root -->[?:Function]] {
        fn_nodes.append({"id": fn.name, "file": fn.file, "type": "function"});
    }

    file_nodes: list[dict] = [];
    for f in [root -->[?:File]] {
        file_nodes.append({"id": f.path, "type": "file"});
    }

    call_edges: list[dict] = [];
    for fn in [root -->[?:Function]] {
        for callee in [fn ->:Calls:->] {
            call_edges.append({"source": fn.name, "target": callee.name});
        }
    }

    return {
        "functions": fn_nodes,
        "files": file_nodes,
        "calls": call_edges
    };
}
sem get_graph = "Return the full ingested call graph as plain JSON (function nodes, file nodes, call edges) so a client can render an interactive node-link graph visualization, separate from any single blast-radius traversal.";
