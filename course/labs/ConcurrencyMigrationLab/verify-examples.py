"""Compile selected complete lesson snippets, keeping all output in a unique scratch path."""
from html.parser import HTMLParser
from pathlib import Path
import json
import os
import subprocess
import tempfile

class SwiftBlocks(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.active = False
        self.blocks = []
    def handle_starttag(self, tag, attrs):
        if tag == "code" and dict(attrs).get("class") == "language-swift":
            self.active = True
            self.blocks.append("")
    def handle_endtag(self, tag):
        if tag == "code":
            self.active = False
    def handle_data(self, data):
        if self.active:
            self.blocks[-1] += data

course = Path(__file__).resolve().parents[2]
unit = json.loads((course / "content/unit-14.json").read_text())
output = Path(tempfile.mkdtemp(prefix="concurrency-examples-089-", dir="/private/tmp"))
env = dict(os.environ, TMPDIR=str(output), CLANG_MODULE_CACHE_PATH=str(output / "clang-cache"),
           SWIFT_MODULECACHE_PATH=str(output / "module-cache"))
results = []
for lesson in unit["lessons"]:
    htmls = [(section["id"], section["html"]) for section in lesson["sections"]]
    htmls.append(("solution", lesson["exercise"]["solution"]))
    for name, html in htmls:
        if lesson["id"] == "089" and name == "warnings-errors":
            continue # Intentionally invalid library global: verified by the settings matrix.
        parser = SwiftBlocks()
        parser.feed(html)
        for index, source in enumerate(parser.blocks):
            label = f"{lesson['id']}-{name}-{index}"
            if lesson["id"] == "090" and name == "solution":
                source = "protocol Caption { func caption() -> String }\n" + source
            file = output / (label + ".swift")
            file.write_text(source)
            flags = ["-enable-upcoming-feature", "NonisolatedNonsendingByDefault"] if lesson["id"] == "089" and name == "caller-execution" else []
            command = ["swiftc", "-disable-sandbox", "-parse-as-library", "-swift-version", "6", "-c", *flags,
                       "-module-cache-path", str(output / "module-cache"), str(file), "-o", str(output / (label + ".o"))]
            result = subprocess.run(command, env=env, text=True, capture_output=True, timeout=60)
            (output / (label + ".txt")).write_text(result.stderr)
            results.append(dict(case=label, passed=result.returncode == 0, command=command))
            print(("PASS " if result.returncode == 0 else "FAIL ") + label)
            if result.returncode:
                print(result.stderr)
(output / "results.json").write_text(json.dumps(results, indent=2))
print("Evidence:", output)
raise SystemExit(0 if all(result["passed"] for result in results) else 1)
