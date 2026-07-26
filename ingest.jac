"""Turns a real repository into the graph defined in graph.jac. Not a
walker - it doesn't traverse the graph, it builds it - so per the
def:pub-vs-walker shape rule this is a plain function endpoint.
"""

import from graph { File, Function, Calls, Imports }
import parser;

obj IngestResult {
    has status: str;
    has repo_path: str;
    has files: int;
    has functions: int;
    has calls: int;
    has imports: int;
}

def:pub ingest_repo(repo_path: str) -> IngestResult {
    # Idempotent: jac run/jac start persist the graph between invocations
    # (see jac-node-edge-patterns), so re-ingesting the same or a different
    # repo must clear what's there first, or nodes silently pile up.
    for f in [root -->[?:File]] {
        del f;
    }
    for fn in [root -->[?:Function]] {
        del fn;
    }

    data = parser.parse_repo(repo_path);

    file_nodes: dict[str, File] = {};
    for f in data["files"] {
        path: str = f["path"] as str;
        made_file = (root ++> File(path=path)) as File;
        file_nodes[path] = made_file;
    }

    fn_nodes: dict[str, Function] = {};
    for fn in data["functions"] {
        name: str = fn["name"] as str;
        file: str = fn["file"] as str;
        source: str = fn["source"] as str;
        made_fn = (root ++> Function(name=name, file=file, source=source)) as Function;
        fn_nodes[name] = made_fn;
    }

    call_count: int = 0;
    for c in data["calls"] {
        caller: str = c["caller"] as str;
        callee: str = c["callee"] as str;
        if caller in fn_nodes and callee in fn_nodes {
            fn_nodes[caller] +>:Calls():+> fn_nodes[callee];
            call_count += 1;
        }
    }

    import_count: int = 0;
    for imp in data["imports"] {
        src: str = imp["src_file"] as str;
        dst: str = imp["dst_file"] as str;
        if src in file_nodes and dst in file_nodes {
            file_nodes[src] +>:Imports():+> file_nodes[dst];
            import_count += 1;
        }
    }

    return IngestResult(
        status="ingested",
        repo_path=repo_path,
        files=len(file_nodes),
        functions=len(fn_nodes),
        calls=call_count,
        imports=import_count
    );
}
