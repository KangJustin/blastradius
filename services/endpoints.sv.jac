"""Server-side entry that re-imports all existing backend modules
so their def:pub and walker:pub endpoints are registered in fullstack mode."""

import from graph { File, Function, Imports, Calls }
import from ingest { ingest_repo, IngestResult }
import from blastradius { BlastRadius }
import from agent { explain_risk }
