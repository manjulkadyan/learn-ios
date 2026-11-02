"""Compile fixtures into a unique temporary directory; never execute invalid code."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parent
output = Path(tempfile.mkdtemp(prefix="concurrency-diagnostics-089-", dir="/private/tmp"))
env = dict(os.environ, TMPDIR=str(output),
           CLANG_MODULE_CACHE_PATH=str(output / "clang-cache"),
           SWIFT_MODULECACHE_PATH=str(output / "module-cache"))
version = subprocess.check_output(["swiftc", "--version"], text=True, env=env)
match = re.search(r"Swift version (\d+)\.(\d+)", version)
if not match or tuple(map(int, match.groups())) < (6, 2):
    raise SystemExit("SKIP: this matrix requires a Swift 6.2+ compiler; no result was verified")

# Name, file, flags, expected success, required diagnostic category on failure/warning.
cases = [
    ("swift5-complete-warning", "MutableGlobal", ["-swift-version", "5", "-strict-concurrency=complete"], True, "warning:"),
    ("swift6-error", "MutableGlobal", ["-swift-version", "6"], False, "concurrency-safe"),
    ("default-nonisolated", "DefaultIsolation", ["-default-isolation", "nonisolated"], True, None),
    ("default-mainactor-error", "DefaultIsolation", ["-default-isolation", "MainActor"], False, "main actor-isolated"),
    ("legacy-async-error", "CallerIsolation", [], False, "data races"),
    ("caller-async-pass", "CallerIsolation", ["-enable-upcoming-feature", "NonisolatedNonsendingByDefault"], True, None),
    ("concurrent-still-error", "ConcurrentBoundary", ["-enable-upcoming-feature", "NonisolatedNonsendingByDefault"], False, "data races"),
    ("transfer-pass", "Transfer", [], True, None),
    ("transfer-use-error", "Transfer", ["-D", "INVALID"], False, "data races"),
    ("isolated-conformance-pass", "Conformance", [], True, None),
    ("isolated-conformance-error", "Conformance", ["-D", "INVALID"], False, "isolated conformance"),
    ("ownership-pass", "Ownership", [], True, None),
    ("ownership-use-error", "Ownership", ["-D", "INVALID"], False, "used after consume"),
    ("exclusivity-error", "Exclusivity", [], False, "not allowed to alias"),
]
results = []
for name, file, flags, success, diagnostic in cases:
    language = [] if "-swift-version" in flags else ["-swift-version", "6"]
    command = ["swiftc", "-parse-as-library", "-c", *language, *flags,
               "-module-cache-path", str(output / "module-cache"),
               str(root / "Diagnostics" / (file + ".swift")), "-o", str(output / (name + ".o"))]
    result = subprocess.run(command, text=True, capture_output=True, env=env, timeout=60)
    (output / (name + ".txt")).write_text(result.stderr)
    passed = (result.returncode == 0) == success and (diagnostic is None or diagnostic in result.stderr)
    results.append(dict(case=name, passed=passed, exit=result.returncode, command=command))
    print(("PASS " if passed else "FAIL ") + name)
    if not passed:
        print(result.stderr)
(output / "results.json").write_text(json.dumps(dict(version=version, results=results), indent=2))
print("Evidence:", output)
raise SystemExit(0 if all(result["passed"] for result in results) else 1)
