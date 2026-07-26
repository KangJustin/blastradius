"""Best-effort, name-based Python call/import graph extraction using the
standard library ``ast`` module. Intended for small demo repos (see the
BlastRadius scoping decision in the project README) - not a full static
analyzer. No third-party dependencies, no network access.
"""

import ast
import os

SKIP_DIRS = {".git", "__pycache__", ".jac", "venv", ".venv", "node_modules"}


def _module_path(repo_root, file_path):
    rel = os.path.relpath(file_path, repo_root)
    if rel.endswith(".py"):
        rel = rel[: -len(".py")]
    parts = rel.split(os.sep)
    if parts[-1] == "__init__":
        parts = parts[:-1]
    return ".".join(parts)


def parse_repo(repo_path):
    """Walk repo_path for .py files and return a graph-shaped record:

    {
      "files": [{"path": rel_path}, ...],
      "functions": [{"name": fn_name, "file": rel_path, "source": src}, ...],
      "calls": [{"caller": fn_name, "callee": fn_name}, ...],
      "imports": [{"src_file": rel_path, "dst_file": rel_path}, ...],
    }
    """
    py_files = []
    for dirpath, dirnames, filenames in os.walk(repo_path):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if fn.endswith(".py"):
                py_files.append(os.path.join(dirpath, fn))

    module_to_file = {}
    file_trees = {}
    for fp in py_files:
        rel = os.path.relpath(fp, repo_path)
        try:
            with open(fp, "r", encoding="utf-8") as fh:
                src = fh.read()
            tree = ast.parse(src, filename=fp)
        except (SyntaxError, UnicodeDecodeError):
            continue
        file_trees[rel] = (tree, src)
        module_to_file[_module_path(repo_path, fp)] = rel

    functions = []
    function_files = {}
    for rel, (tree, src) in file_trees.items():
        src_lines = src.splitlines()
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                start = node.lineno - 1
                end = getattr(node, "end_lineno", start + 1)
                snippet = "\n".join(src_lines[start:end])[:2000]
                functions.append({"name": node.name, "file": rel, "source": snippet})
                function_files.setdefault(node.name, rel)

    calls = []
    seen_calls = set()
    for rel, (tree, _src) in file_trees.items():
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                caller = node.name
                for child in ast.walk(node):
                    if isinstance(child, ast.Call):
                        target = None
                        if isinstance(child.func, ast.Name):
                            target = child.func.id
                        elif isinstance(child.func, ast.Attribute):
                            target = child.func.attr
                        if target and target in function_files and target != caller:
                            key = (caller, target)
                            if key not in seen_calls:
                                seen_calls.add(key)
                                calls.append({"caller": caller, "callee": target})

    imports = []
    seen_imports = set()
    for rel, (tree, _src) in file_trees.items():
        for node in ast.walk(tree):
            dst = None
            if isinstance(node, ast.Import):
                for alias in node.names:
                    dst = module_to_file.get(alias.name)
                    if dst and dst != rel:
                        key = (rel, dst)
                        if key not in seen_imports:
                            seen_imports.add(key)
                            imports.append({"src_file": rel, "dst_file": dst})
            elif isinstance(node, ast.ImportFrom) and node.module:
                dst = module_to_file.get(node.module)
                if dst and dst != rel:
                    key = (rel, dst)
                    if key not in seen_imports:
                        seen_imports.add(key)
                        imports.append({"src_file": rel, "dst_file": dst})

    return {
        "files": [{"path": rel} for rel in file_trees],
        "functions": functions,
        "calls": calls,
        "imports": imports,
    }
