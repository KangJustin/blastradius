"""Graph schema for BlastRadius: a repo's functions/files and their real
call/import relationships. This is the actual data structure the app is
built around - everything else (ingest, traversal, the agent) reads and
writes this graph.
"""

node File {
    has path: str;
}

node Function {
    has name: str;
    has file: str;
    has source: str = "";
}

edge Imports: File --> File {}
edge Calls: Function --> Function {}
