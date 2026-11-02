#!/usr/bin/env python3
"""Validate only this worker's three banks and bounded lab links; writes nothing."""
import html
import json
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse

COURSE = Path(__file__).resolve().parents[3]
ROOT = COURSE.parent.parent
CONTENT = COURSE / "content"
ALLOWED = set("p h3 h4 ul ol li strong em code pre table thead tbody tr th td blockquote details summary a".split())
OFFICIAL = {"developer.apple.com", "docs.swift.org", "kotlinlang.org", "developer.android.com", "docs.oracle.com"}

class Fragment(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.text = []
        self.code_depth = 0

    def handle_starttag(self, tag, attrs):
        assert tag in ALLOWED, f"Unsupported tag: {tag}"
        for key, value in attrs:
            assert (tag == "code" and key == "class" and value.startswith("language-")) or (
                tag == "a" and key == "href" and urlparse(value).scheme == "https"
            ), f"Unsafe attribute: {tag} {key}"
        self.stack.append(tag)
        if tag in {"pre", "code"}:
            self.code_depth += 1

    def handle_endtag(self, tag):
        assert self.stack and self.stack.pop() == tag, f"Unbalanced tag: {tag}"
        if tag in {"pre", "code"}:
            self.code_depth -= 1

    def handle_data(self, text):
        if not self.code_depth:
            self.text.append(text)

def fragment(value):
    assert isinstance(value, str) and value
    parser = Fragment()
    parser.feed(value)
    parser.close()
    assert not parser.stack, parser.stack
    return len(re.findall(r"\S+", " ".join(parser.text)))

def refs(values):
    assert len(values) >= 2
    official = 0
    for ref in values:
        assert ref["label"]
        parsed = urlparse(ref["url"])
        assert parsed.scheme == "https" and parsed.netloc and parsed.path != "/"
        official += parsed.netloc in OFFICIAL
    assert official >= 2

def sections(values, minimum):
    assert len(values) >= minimum
    assert len({s["id"] for s in values}) == len(values)
    return sum(fragment(s["html"]) for s in values)

def exercise(value):
    assert value["brief"] and value["steps"] and value["acceptance"]
    assert len(value["acceptance"]) >= 3
    return fragment(value["solution"])

def quiz(values):
    assert len(values) >= 3
    for q in values:
        assert q["question"] and len(q["options"]) >= 3
        assert type(q["answer"]) is int and 0 <= q["answer"] < len(q["options"])
        assert q["explanation"]

unit = json.loads((CONTENT / "unit-15.json").read_text())
assert unit["unit"]["id"] == "ui-runtime-lifecycle" and unit["unit"]["order"] == 15
assert [l["id"] for l in unit["lessons"]] == ["093", "094", "095", "096"]
known = set()
for path in CONTENT.glob("unit-*.json"):
    if int(path.stem.split("-")[1]) > 12:
        continue
    for lesson in json.loads(path.read_text())["lessons"]:
        if int(lesson["id"]) <= 84:
            known.add(lesson["id"])
for lesson in unit["lessons"]:
    assert lesson["summary"] and lesson["objectives"] and lesson["checklist"]
    words = sections(lesson["sections"], 5) + exercise(lesson["exercise"])
    assert words >= 1300, (lesson["id"], words)
    quiz(lesson["quiz"])
    refs(lesson["references"])
    for dependency in lesson["prerequisites"]:
        assert dependency in known | {"093", "094", "095", "096"}
        assert int(dependency) < int(lesson["id"])
    assert lesson["repo"]
    for anchor in lesson["repo"]:
        assert anchor["path"].startswith("ios-client/") and ".." not in Path(anchor["path"]).parts
        lines = (ROOT / anchor["path"]).read_text().splitlines()
        assert type(anchor["line"]) is int and 1 <= anchor["line"] <= len(lines)
        assert lines[anchor["line"] - 1].strip() and anchor["why"]
    print(f"PASS lesson {lesson['id']}: {words} prose words, {len(lesson['sections'])} sections, {len(lesson['repo'])} existing anchors")

interviews = json.loads((CONTENT / "interview-ui-runtime.json").read_text())["questions"]
assert {q["id"] for q in interviews} == {f"iq-{n:03}-{letter}" for n in range(93, 97) for letter in "ab"}
for q in interviews:
    assert q["id"] == f"iq-{q['lesson']}-{q['id'][-1]}"
    assert q["level"] in {"Foundation", "Senior", "Staff"}
    assert q["kind"] in {"Explain", "Debug", "Design", "Code"}
    assert 3 <= q["minutes"] <= 20
    assert all(q[k] for k in ["prompt", "scenario", "androidBridge"])
    assert len(q["rubric"]) >= 4 and len(q["followUps"]) >= 2 and len(q["pitfalls"]) >= 2
    words = fragment(q["answerHTML"])
    assert 100 <= words <= 220, (q["id"], words)
    print(f"PASS interview {q['id']}: {words} model-answer words")

practice = json.loads((CONTENT / "practice-ui-runtime.json").read_text())["workshops"]
assert len(practice) == 1 and practice[0]["id"] == "ui-runtime-lab"
w = practice[0]
assert w["kind"] == "Native implementation" and w["sessions"] == ["093", "094", "095", "096"]
words = sections(w["sections"], 4) + exercise(w["exercise"])
assert words >= 900
quiz(w["quiz"])
refs(w["references"])
assert w["files"]
for link in w["files"]:
    parts = Path(link["path"]).parts
    assert parts[:2] == ("labs", "UIRuntimeLab") and ".." not in parts
    assert all(not p.startswith(".") for p in parts)
    assert (COURSE / link["path"]).is_file() and link["label"]
print(f"PASS workshop {w['id']}: {words} prose words, {len(w['files'])} bounded existing files")
print("PASS scoped JSON/HTML/prerequisite/quiz/reference/anchor validation; shared integration not run")
