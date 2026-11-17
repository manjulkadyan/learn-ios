"""Read-only audit of this author's content and artifact scope."""
import html.parser
import json
import pathlib
import re
from urllib.parse import urlparse

root = pathlib.Path(__file__).resolve().parent
course = root.parents[1]
workspace = course.parent.parent
load = lambda name: json.loads((course / "content" / name).read_text())
words = lambda value: len(re.sub(r"<[^>]+>", " ", value).split())

class SafeHTML(html.parser.HTMLParser):
    allowed = set("p h3 h4 ul ol li strong em code pre table thead tbody tr th td blockquote details summary a br caption".split())
    attributes = {"class", "href", "title", "scope", "colspan", "rowspan"}
    def __init__(self):
        super().__init__(); self.stack = []
    def handle_starttag(self, tag, attrs):
        assert tag in self.allowed, f"Unexpected tag {tag}"
        for key, value in attrs:
            assert key in self.attributes and value is not None
            if key == "href": assert value.startswith("https://"), "Prose links require HTTPS"
        if tag != "br": self.stack.append(tag)
    def handle_endtag(self, tag):
        assert self.stack and self.stack.pop() == tag, f"Unbalanced {tag}"

def safe(value):
    assert isinstance(value, str) and value.strip()
    parser = SafeHTML(); parser.feed(value); parser.close()
    assert not parser.stack, parser.stack

def simple(value):
    assert set(value) == {"story", "meaning", "example", "picture", "words", "remember", "boundary"}
    for key in ["story", "meaning", "remember", "boundary"]:
        assert isinstance(value[key], str) and value[key].strip() and "<" not in value[key]
    assert set(value["example"]) == {"before", "change", "after"}
    assert all(isinstance(x, str) and x.strip() for x in value["example"].values())
    picture = value["picture"]
    assert picture["kind"] in ["flow", "timeline", "comparison"]
    assert picture["caption"] and 3 <= len(picture["items"]) <= 5
    assert all(x["label"] and x["text"] for x in picture["items"])
    assert 3 <= len(value["words"]) <= 7
    assert len({x["term"].lower() for x in value["words"]}) == len(value["words"])
    assert all(x["term"] and x["meaning"] for x in value["words"])

def teaching(item, minimum_sections, minimum_words):
    simple(item["simple"])
    assert len(item["sections"]) >= minimum_sections
    ids = [s["id"] for s in item["sections"]]
    assert len(set(ids)) == len(ids) and all(re.fullmatch(r"[a-z0-9-]+", x) for x in ids)
    for section in item["sections"]: safe(section["html"]); assert section["title"]
    exercise = item["exercise"]
    assert exercise["brief"] and exercise["steps"] and exercise["acceptance"]
    safe(exercise["solution"])
    assert len(item["quiz"]) == 3
    for quiz in item["quiz"]:
        assert quiz["question"] and quiz["explanation"] and len(quiz["options"]) >= 3
        assert isinstance(quiz["answer"], int) and 0 <= quiz["answer"] < len(quiz["options"])
    assert len(item["references"]) >= 2
    for reference in item["references"]:
        parsed = urlparse(reference["url"])
        assert parsed.scheme == "https" and parsed.netloc in {"docs.swift.org", "developer.apple.com", "www.swift.org"}
        assert reference["label"]
    count = words(" ".join(s["html"] for s in item["sections"]) + " " + exercise["solution"])
    assert count >= minimum_words, (item["id"], count)
    print(f"PASS {item['id']}: {count} teaching words, {len(ids)} sections, 3 explained checks")

unit = load("unit-27.json")
assert unit["unit"]["id"] == "architecture-course" and unit["unit"]["order"] == 27
assert [x["id"] for x in unit["lessons"]] == ["145", "146", "147", "148"]
curriculum = load("curriculum.json")
sequence = [lesson for stage in curriculum["stages"] + curriculum["extensions"] for lesson in stage["lessons"]]
rank = {lesson: index for index, lesson in enumerate(sequence)}
assert len(rank) == len(sequence)
for lesson in unit["lessons"]:
    teaching(lesson, 5, 1300)
    assert 15 <= lesson["duration"] <= 180 and lesson["objectives"] and lesson["checklist"]
    for prerequisite in lesson["prerequisites"]:
        assert prerequisite in rank and rank[prerequisite] < rank[lesson["id"]], (lesson["id"], prerequisite)
    assert lesson["repo"]
    for anchor in lesson["repo"]:
        assert anchor["path"].startswith("ios-client/") and anchor["why"]
        source = (workspace / anchor["path"]).read_text().splitlines()
        assert 1 <= anchor["line"] <= len(source)
    print(f"PASS {lesson['id']} prerequisite sequence: {', '.join(lesson['prerequisites'])}")

questions = load("interview-architecture.json")["questions"]
assert [q["id"] for q in questions] == [f"iq-{n}-{suffix}" for n in range(145, 149) for suffix in ["a", "b"]]
for question in questions:
    assert question["lesson"] == question["id"][3:6]
    assert question["level"] in ["Foundation", "Senior", "Staff"] and question["kind"] in ["Explain", "Debug", "Design", "Code"]
    assert 3 <= question["minutes"] <= 20 and len(question["rubric"]) >= 4
    assert len(question["followUps"]) >= 2 and len(question["pitfalls"]) >= 2
    assert question["prompt"] and question["scenario"] and question["androidBridge"]
    safe(question["answerHTML"]); assert 100 <= words(question["answerHTML"]) <= 220
print("PASS eight interview identities, budgets, rubrics, and explained answer lengths")

workshops = load("practice-architecture.json")["workshops"]
assert len(workshops) == 1
workshop = workshops[0]
assert workshop["id"] == "architecture-course" and workshop["kind"] == "Host implementation"
assert workshop["sessions"] == ["145", "146", "147", "148"]
teaching(workshop, 4, 900)
registered = set()
for artifact in workshop["files"]:
    path = pathlib.PurePosixPath(artifact["path"])
    assert str(path).startswith("labs/ArchitectureProject/") and artifact["label"]
    assert all(part and not part.startswith(".") for part in path.parts)
    resolved = (course / path).resolve()
    assert resolved.is_relative_to(root) and resolved.is_file() and resolved.stat().st_size <= 500_000
    assert "\0" not in resolved.read_text()
    registered.add(resolved)
sources = {p.resolve() for p in root.rglob("*") if p.is_file() and not any(part.startswith(".") for part in p.relative_to(root).parts)}
assert registered == sources, f"Artifact registration differs: {registered ^ sources}"
print(f"PASS {len(registered)} bounded text artifacts; all client anchors resolve; no shared output generated")
