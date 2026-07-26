"""Entry point. A Jac server only reliably registers an endpoint when its
exact name is imported here (see jac-sv-endpoints / jac-fullstack-patterns)
- so every public function/walker in the app is named in this import block,
even though each is implemented in its own module.
"""

import from graph { File, Function, Imports, Calls }
import from ingest { ingest_repo, IngestResult }
import from blastradius { BlastRadius }
import from agent { explain_risk }
import from graphdata { get_graph }
