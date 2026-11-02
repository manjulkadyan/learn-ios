"""Read-only validation of this assignment; does not build/register the course."""
import html
import json
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse

COURSE = Path(__file__).resolve().parents[3]
WORKSPACE = COURSE.parents[1]
TAGS = set("p h3 h4 ul ol li strong em code pre table thead tbody tr th td blockquote details summary a".split())

class SafeHTML(HTMLParser):
    def __init__(self):
        super().__init__()
        self.stack = []

    def handle_starttag(self, tag, attrs):
        assert tag in TAGS, f"Unsupported tag: {tag}"
        for name, value in attrs:
            assert name in {"class", "href", "title", "scope", "colspan", "rowspan"}
            if name == "href":
                assert urlparse(value).scheme == "https"
            if name == "class":
                assert tag == "code" and value == "language-swift"
        self.stack.append(tag)

    def handle_endtag(self, tag):
        assert self.stack and self.stack.pop() == tag, f"Unbalanced tag: {tag}"

    def handle_comment(self, data):
        raise AssertionError("Unexpected HTML comment")

def validate_html(value):
    parser = SafeHTML()
    parser.feed(value)
    parser.close()
    assert not parser.stack

def words(value):
    # Stricter than the builder: exclude code listings from teaching prose depth.
    prose = re.sub(r"<pre>.*?</pre>", " ", value, flags=re.S)
    return len(re.findall(r"\b[\w'-]+\b", html.unescape(re.sub(r"<[^>]+>", " ", prose))))

def teaching(item, minimum_sections, minimum_words):
    assert len(item["sections"]) >= minimum_sections
    assert len({s["id"] for s in item["sections"]}) == len(item["sections"])
    blocks = [s["html"] for s in item["sections"]] + [item["exercise"]["solution"]]
    for block in blocks:
        validate_html(block)
    count = sum(map(words, blocks))
    assert count >= minimum_words, (item["id"], count)
    assert item["exercise"]["steps"] and item["exercise"]["acceptance"]
    assert len(item["quiz"]) >= 3
    for quiz in item["quiz"]:
        assert len(quiz["options"]) >= 3
        assert 0 <= quiz["answer"] < len(quiz["options"])
        assert quiz["explanation"].strip()
    assert len(item["references"]) >= 2
    for reference in item["references"]:
        parsed = urlparse(reference["url"])
        assert parsed.scheme == "https"
        assert parsed.netloc in {"developer.apple.com", "docs.swift.org", "developer.android.com", "docs.oracle.com", "kotlinlang.org", "github.com"}
        if parsed.netloc == "github.com":
            assert parsed.path.startswith("/swiftlang/swift-evolution/")
    print(f"{item['id']}: {count} prose words, HTML/exercise/quiz/reference checks passed")

def read(name):
    return json.loads((COURSE / "content" / name).read_text())

unit = read("unit-13.json")
assert unit["unit"]["id"] == "runtime-scheduling" and unit["unit"]["order"] == 13
assert [l["id"] for l in unit["lessons"]] == ["085", "086", "087", "088"]
known = {l["id"] for n in range(1, 14) for l in read(f"unit-{n:02}.json")["lessons"]}
anchor_tokens = {"085": "scheduler: RunLoop.main", "086": "self.queue = DispatchQueue", "087": "exitLock.withLock", "088": "Task.detached(priority: .userInitiated)"}
for lesson in unit["lessons"]:
    teaching(lesson, 5, 1300)
    assert all(p in known and int(p) < int(lesson["id"]) for p in lesson["prerequisites"])
    assert lesson["repo"]
    for anchor in lesson["repo"]:
        source = WORKSPACE / anchor["path"]
        assert source.resolve().is_relative_to(WORKSPACE.resolve())
        lines = source.read_text().splitlines()
        assert 1 <= anchor["line"] <= len(lines)
        assert anchor_tokens[lesson["id"]] in lines[anchor["line"] - 1]

questions = read("interview-runtime.json")["questions"]
expected = {f"iq-{n:03}-{suffix}" for n in range(85, 89) for suffix in "ab"}
assert len(questions) == 8 and {q["id"] for q in questions} == expected
for question in questions:
    assert question["id"].split("-")[1] == question["lesson"]
    assert 3 <= question["minutes"] <= 20
    assert question["level"] in {"Foundation", "Senior", "Staff"}
    assert question["kind"] in {"Explain", "Debug", "Design", "Code"}
    assert len(question["rubric"]) >= 4
    assert len(question["followUps"]) >= 2 and len(question["pitfalls"]) >= 2
    validate_html(question["answerHTML"])
    assert 100 <= words(question["answerHTML"]) <= 220

workshops = read("practice-runtime.json")["workshops"]
assert len(workshops) == 1
workshop = workshops[0]
assert workshop["id"] == "runtime-scheduling-lab"
assert set(workshop["sessions"]) == {"085", "086", "087", "088"}
teaching(workshop, 4, 900)
for artifact in workshop["files"]:
    assert artifact["path"].startswith("labs/RuntimeLab/")
    assert all(part and not part.startswith(".") for part in artifact["path"].split("/"))
    file = COURSE / artifact["path"]
    assert file.resolve().is_relative_to((COURSE / "labs/RuntimeLab").resolve())
    assert file.is_file() and file.stat().st_size < 500_000
    assert "\0" not in file.read_text()
print("PASS: four lessons, eight interviews, one workshop, lower prerequisites, four inspected anchors and bounded explicit artifacts; no global build")
