"""Validate only this author's assigned unit/banks; never invoke the global build."""
import html
import json
import re
from html.parser import HTMLParser
from pathlib import Path

COURSE = Path(__file__).resolve().parents[2]
WORKSPACE = Path(__file__).resolve().parents[4]
ALLOWED = set("p h3 h4 ul ol li strong em code pre table thead tbody tr th td blockquote details summary a".split())

class SafeHTML(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
    def handle_starttag(self, tag, attrs):
        assert tag in ALLOWED, f"unsafe element {tag}"
        for key, value in attrs:
            assert (tag == "code" and key == "class" and value.startswith("language-")) or (
                tag == "a" and key == "href" and value.startswith("https://")), f"unsafe attribute {key}"
        self.stack.append(tag)
    def handle_endtag(self, tag):
        assert self.stack and self.stack.pop() == tag, f"unbalanced {tag}"

def safe(value):
    parser = SafeHTML()
    parser.feed(value)
    parser.close()
    assert not parser.stack, "unclosed HTML"

def words(value):
    value = re.sub(r"<pre>[\s\S]*?</pre>", " ", value)
    value = html.unescape(re.sub(r"<[^>]*>", " ", value))
    return len(value.split())

def load(name):
    return json.loads((COURSE / "content" / name).read_text())

def teaching(item, minimum, sections):
    assert len(item["sections"]) >= sections
    assert len({s["id"] for s in item["sections"]}) == len(item["sections"])
    count = 0
    for section in item["sections"]:
        safe(section["html"])
        count += words(section["html"])
    exercise = item["exercise"]
    assert exercise["brief"] and exercise["steps"] and exercise["acceptance"]
    safe(exercise["solution"])
    count += words(exercise["solution"])
    assert count >= minimum, (item["id"], count)
    assert len(item["quiz"]) >= 3
    for quiz in item["quiz"]:
        assert len(quiz["options"]) >= 3 and type(quiz["answer"]) is int
        assert 0 <= quiz["answer"] < len(quiz["options"]) and quiz["explanation"]
    assert len(item["references"]) >= 2
    assert all(r["url"].startswith("https://") for r in item["references"])
    print(f"PASS teaching {item['id']}: {count} prose words; HTML, exercise, quizzes, references")

unit = load("unit-16.json")
assert unit["unit"]["id"] == "durable-data-recovery" and unit["unit"]["order"] == 16
assert [x["id"] for x in unit["lessons"]] == ["097", "098", "099", "100"]
known = set()
for path in (COURSE / "content").glob("unit-*.json"):
    for lesson in json.loads(path.read_text())["lessons"]:
        if 1 <= int(lesson["id"]) <= 84:
            known.add(lesson["id"])
for lesson in unit["lessons"]:
    assert all(p in known and int(p) < int(lesson["id"]) for p in lesson["prerequisites"])
    teaching(lesson, 1300, 5)
    assert lesson["repo"]
    for anchor in lesson["repo"]:
        path = WORKSPACE / anchor["path"]
        assert anchor["path"].startswith("ios-client/Projects/") and path.is_file()
        assert 1 <= anchor["line"] <= len(path.read_text().splitlines())
    known.add(lesson["id"])
questions = load("interview-durable-data.json")["questions"]
expected = {f"iq-{lesson}-{suffix}" for lesson in ["097", "098", "099", "100"] for suffix in ["a", "b"]}
assert len(questions) == 8 and {q["id"] for q in questions} == expected
for question in questions:
    assert question["lesson"] in known and question["id"].startswith(f"iq-{question['lesson']}-")
    assert question["level"] in ["Foundation", "Senior", "Staff"]
    assert question["kind"] in ["Explain", "Debug", "Design", "Code"]
    assert 3 <= question["minutes"] <= 20 and question["scenario"] and question["androidBridge"]
    assert len(question["rubric"]) >= 4 and len(question["followUps"]) >= 2 and len(question["pitfalls"]) >= 2
    safe(question["answerHTML"])
    assert words(question["answerHTML"]) >= 100
print("PASS 8 interview identities, model answers, rubrics, follow-ups and pitfalls")
workshops = load("practice-durable-data.json")["workshops"]
assert len(workshops) == 1 and workshops[0]["id"] == "durable-data-lab"
workshop = workshops[0]
teaching(workshop, 900, 4)
assert workshop["kind"] == "Host implementation" and set(workshop["sessions"]) <= known
for artifact in workshop["files"]:
    path = Path(artifact["path"])
    assert artifact["path"].startswith("labs/DurableDataLab/")
    assert not any(part == ".." or part.startswith(".") for part in path.parts)
    assert (COURSE / path).is_file(), artifact
print("PASS owned explicit lab artifacts and inspected anchor locations")
