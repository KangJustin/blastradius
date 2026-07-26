"""jac test coverage for the deterministic core: parsing a real repo into
the graph, and the BlastRadius walker's bounded traversal over it. Run
from the project root: `jac clean --all --force && jac test`.
"""

import from graph { File, Function, Calls }
import from ingest { ingest_repo }
import from blastradius { BlastRadius }

test "ingest_repo builds the expected graph from a real fixture repo" {
    result = ingest_repo("tests/fixture_repo");

    assert result.status == "ingested";
    assert result.files == 2;
    assert result.functions == 4;
    # main -> process, process -> helper: 2 real intra-repo calls.
    # `unrelated` in utils.py calls nothing in the fixture repo.
    assert result.calls == 2;

    files = [root -->[?:File]];
    assert len(files) == 2;
    fns = [root -->[?:Function]];
    assert len(fns) == 4;
}

test "ingest_repo is idempotent - re-ingesting does not duplicate nodes" {
    ingest_repo("tests/fixture_repo");
    ingest_repo("tests/fixture_repo");

    fns = [root -->[?:Function]];
    assert len(fns) == 4;
}

test "BlastRadius finds the real call chain, not unrelated functions" {
    ingest_repo("tests/fixture_repo");

    result = root spawn BlastRadius(target_fn="helper", max_hops=3);
    names = [f.name for f in result.reports];

    assert "helper" in names;
    assert "process" in names;   # calls helper directly
    assert "main" in names;      # calls process, which calls helper
    assert "unrelated" not in names;
}

test "BlastRadius respects max_hops" {
    ingest_repo("tests/fixture_repo");

    result = root spawn BlastRadius(target_fn="helper", max_hops=0);
    names = [f.name for f in result.reports];

    assert names == ["helper"];
    assert result.found;
}

test "BlastRadius signals not-found for a nonexistent target_fn" {
    ingest_repo("tests/fixture_repo");

    result = root spawn BlastRadius(target_fn="does_not_exist", max_hops=3);

    assert not result.found;
    assert result.reports == [];
}

test "ingest_repo raises clearly on a nonexistent repo path" {
    try {
        ingest_repo("tests/does_not_exist_at_all");
        assert False, "should have raised";
    } except FileNotFoundError {
        assert True;
    }
}
