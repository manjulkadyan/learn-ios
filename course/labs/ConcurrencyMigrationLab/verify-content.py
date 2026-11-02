"""Audit only unit 14 and its assigned banks; this is not the global course builder."""
from html.parser import HTMLParser
from pathlib import Path
import json
import re

course = Path(__file__).resolve().parents[2]
workspace = course.parents[1]
content = course / "content"
allowed = set("p h3 h4 ul ol li strong em code pre table thead tbody tr th td blockquote details summary a".split())

class SafeTeaching(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.words = []
        self.pre = 0
    def handle_starttag(self, tag, attrs):
        assert tag in allowed, tag
        for key, value in attrs:
            assert (tag == "code" and key == "class") or (tag == "a" and key == "href"), (tag, key)
            if key == "href":
                assert value.startswith("https://"), value
        if tag == "pre":
            self.pre += 1
    def handle_endtag(self, tag):
        assert tag in allowed, tag
        if tag == "pre":
            self.pre -= 1
            assert self.pre >= 0
    def handle_data(self, data):
        if self.pre == 0:
            self.words.extend(re.findall(r"\b[\w]+(?:[-’'][\w]+)*\b", data))

def count(html):
    parser = SafeTeaching()
    parser.feed(html)
    assert parser.pre == 0
    return len(parser.words)

def quizzes(items):
    assert len(items) >= 3
    for item in items:
        assert len(item["options"]) >= 3
        assert type(item["answer"]) is int and 0 <= item["answer"] < len(item["options"])
        assert item["explanation"]

def teaching(item, minimum, sections):
    assert len(item["sections"]) >= sections
    assert len({section["id"] for section in item["sections"]}) == len(item["sections"])
    total = sum(count(section["html"]) for section in item["sections"]) + count(item["exercise"]["solution"])
    assert total >= minimum, (item["id"], total)
    assert item["exercise"]["acceptance"] and item["exercise"]["steps"]
    assert len(item["references"]) >= 2
    assert all(reference["url"].startswith("https://") for reference in item["references"])
    quizzes(item["quiz"])
    print(item["id"], "teaching words excluding pre blocks:", total)

unit = json.loads((content / "unit-14.json").read_text())
assert unit["unit"]["id"] == "concurrency-migration" and unit["unit"]["order"] == 14
assert [lesson["id"] for lesson in unit["lessons"]] == ["089", "090", "091", "092"]
known = {lesson["id"] for path in content.glob("unit-*.json")
         for lesson in json.loads(path.read_text())["lessons"] if int(lesson["id"]) <= 84}
for lesson in unit["lessons"]:
    teaching(lesson, 1300, 5)
    assert all(prerequisite in known and int(prerequisite) < int(lesson["id"])
               for prerequisite in lesson["prerequisites"])
    assert lesson["repo"]
    for anchor in lesson["repo"]:
        source = workspace / anchor["path"]
        lines = source.read_text().splitlines()
        assert 1 <= anchor["line"] <= len(lines)
        assert lines[anchor["line"] - 1].strip()
        print("anchor", anchor["path"], anchor["line"], lines[anchor["line"] - 1].strip())
    known.add(lesson["id"])

questions = json.loads((content / "interview-concurrency.json").read_text())["questions"]
assert len(questions) == 8
assert {question["id"] for question in questions} == {f"iq-{lesson}-{suffix}" for lesson in ("089", "090", "091", "092") for suffix in "ab"}
for question in questions:
    assert question["id"].split("-")[1] == question["lesson"]
    words = count(question["answerHTML"])
    assert 100 <= words <= 220, (question["id"], words)
    assert len(question["rubric"]) >= 4 and len(question["followUps"]) >= 2 and len(question["pitfalls"]) >= 2
    assert question["level"] in ("Foundation", "Senior", "Staff")
    assert question["kind"] in ("Explain", "Debug", "Design", "Code")
    assert 3 <= question["minutes"] <= 20
    print(question["id"], "model-answer words:", words)

workshops = json.loads((content / "practice-concurrency.json").read_text())["workshops"]
assert len(workshops) == 1 and workshops[0]["id"] == "swift6-migration-lab"
for workshop in workshops:
    teaching(workshop, 900, 4)
    assert workshop["kind"] == "Host implementation"
    assert all(session in known for session in workshop["sessions"])
    for file in workshop["files"]:
        path = Path(file["path"])
        assert path.parts[:2] == ("labs", "ConcurrencyMigrationLab")
        assert not any(part.startswith(".") for part in path.parts)
        assert (course / path).is_file(), path
print("PASS: assigned content, prerequisites, HTML, quizzes, references, anchors and explicit files")
