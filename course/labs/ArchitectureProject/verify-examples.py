"""Typecheck complete Swift lesson snippets against the built host domain module."""
import html
import json
import pathlib
import platform
import re
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parent
unit = json.loads((root.parents[1] / "content" / "unit-27.json").read_text())
modules = list(pathlib.Path("/private/tmp/architecture-project-host").rglob("NoteDomain.swiftmodule"))
assert modules, "Run sh verify-host.sh first to build public companion modules"
module_path = modules[0].parent
output = pathlib.Path(tempfile.mkdtemp(prefix="architecture-snippets-", dir="/private/tmp"))
sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip()
arch = "arm64" if platform.machine() == "arm64" else "x86_64"
count = 0
for lesson in unit["lessons"]:
    blocks = [section["html"] for section in lesson["sections"]] + [lesson["exercise"]["solution"]]
    snippets = [html.unescape(match) for block in blocks for match in re.findall(r'<pre><code class="language-swift">(.*?)</code></pre>', block, re.S)]
    assert len(snippets) == 1, "Each lesson intentionally has one complete independently checked Swift snippet"
    source = output / f"Lesson{lesson['id']}.swift"
    source.write_text(snippets[0])
    subprocess.run(["xcrun", "--sdk", "macosx", "swiftc", "-disable-sandbox", "-swift-version", "6",
                    "-target", f"{arch}-apple-macosx14.0", "-sdk", sdk, "-module-cache-path", str(output / "ModuleCache"),
                    "-I", str(module_path), "-parse-as-library", "-typecheck", "-module-name", f"Lesson{lesson['id']}", str(source)], check=True)
    print(f"PASS lesson {lesson['id']} Swift snippet typechecked")
    count += 1
print(f"PASS {count} snippets. Typechecking is not exercise completion or native app interaction.")
