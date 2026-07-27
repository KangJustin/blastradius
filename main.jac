"""Entry point for the Blast Radius Analyzer fullstack app.
Server imports register the backend endpoints; client section renders the UI."""

import from graph { File, Function, Imports, Calls }
import from ingest { ingest_repo, IngestResult }
import from blastradius { BlastRadius }
import from agent { explain_risk, suggest_tests, RiskAssessment }
import from graphdata { get_graph, GraphData }

import ".styles.global.css";
import from .components.BlastAnalyzer { BlastAnalyzer }

def:pub app() -> JsxElement {
    return <BlastAnalyzer />;
}
