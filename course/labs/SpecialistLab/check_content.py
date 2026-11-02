"""Validate ONLY unit 19, its two banks and bounded companion text.

No global assembly, integration changes, progress writes or network requests.
Python 3.11+, standard library only. Exit nonzero on a contract failure.
"""
from html import unescape
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import urlparse

COURSE = Path(__file__).resolve().parents[2]
WORKSPACE = COURSE.parents[1]
ALLOWED_TAGS = {
    "p", "h3", "h4", "ul", "ol", "li", "strong", "em", "code", "pre",
    "table", "thead", "tbody", "tr", "th", "td", "blockquote", "details",
    "summary", "a",
}
COMPANIONS = {
    "labs/SpecialistLab/policy_model.py",
    "labs/SpecialistLab/test_policy.py",
    "labs/SpecialistLab/SnippetChecks.swift",
    "labs/SpecialistLab/README.md",
    "labs/SpecialistLab/NativeChecklist.md",
    "labs/SpecialistLab/check_content.py",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


class SafeHTML(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.prose = []
        self.code_blocks = []
        self.current_code = None

    def handle_starttag(self, tag, attrs):
        require(tag in ALLOWED_TAGS, f"unsafe/unsupported HTML tag {tag}")
        for key, value in attrs:
            valid = (tag == "code" and key == "class" and value == "language-swift")
            valid |= (tag == "a" and key == "href" and urlparse(value).scheme == "https")
            require(valid, f"unsupported attribute {tag}.{key}")
        self.stack.append(tag)
        if tag == "pre":
            self.current_code = []

    def handle_endtag(self, tag):
        require(self.stack and self.stack[-1] == tag, f"unbalanced HTML closing {tag}")
        self.stack.pop()
        if tag == "pre":
            self.code_blocks.append("".join(self.current_code))
            self.current_code = None

    def handle_data(self, data):
        if self.current_code is not None:
            self.current_code.append(data)
        else:
            self.prose.append(data)

    def handle_startendtag(self, tag, attrs):
        raise ValueError(f"unsupported self-closing tag {tag}")

    def handle_comment(self, data):
        raise ValueError("HTML comments are outside the authoring contract")


def html(text):
    require(isinstance(text, str) and text.strip(), "empty HTML")
    parser = SafeHTML()
    parser.feed(text)
    parser.close()
    require(not parser.stack, f"unclosed HTML tags {parser.stack}")
    return parser


def words(text):
    # Count original prose, excluding preformatted code, after entity decoding.
    return len(re.findall(r"\S+", " ".join(html(text).prose)))


def refs(items):
    require(len(items) >= 2, "need two precise official references")
    for item in items:
        require(item["label"].strip(), "empty reference label")
        parsed = urlparse(item["url"])
        require(parsed.scheme == "https" and parsed.netloc in {
            "developer.apple.com", "docs.swift.org", "developer.android.com", "kotlinlang.org",
        } and len(parsed.path) > 1, "reference must be a precise official HTTPS URL")


def quiz(items):
    require(len(items) >= 3, "need three explained MCQs")
    for q in items:
        require(q["question"].strip() and len(q["options"]) >= 3, "invalid MCQ")
        require(type(q["answer"]) is int and 0 <= q["answer"] < len(q["options"]), "bad quiz answer")
        require(len(q["explanation"].split()) >= 10, "MCQ needs a mechanism explanation")


def teaching(item, section_floor, word_floor):
    require(len(item["sections"]) >= section_floor, "insufficient sections")
    ids = [s["id"] for s in item["sections"]]
    require(len(ids) == len(set(ids)), "duplicate section ID")
    for s in item["sections"]:
        require(s["title"].strip(), "empty section title")
        html(s["html"])
    e = item["exercise"]
    require(e["brief"].strip() and len(e["steps"]) >= 3 and len(e["acceptance"]) >= 3,
            "exercise must be independent with explicit acceptance")
    require(words(e["solution"]) >= 250, "worked solution must explain a substantial answer")
    total = sum(words(s["html"]) for s in item["sections"]) + words(e["solution"])
    require(total >= word_floor, f"prose word floor: {item['id']} has {total}, needs {word_floor}")
    refs(item["references"])
    quiz(item["quiz"])
    return total


def read(name):
    return json.loads((COURSE / "content" / name).read_text())


def main():
    unit = read("unit-19.json")
    require(unit["unit"]["id"] == "apple-specialists" and unit["unit"]["order"] == 19,
            "wrong unit identity")
    lessons = unit["lessons"]
    require([l["id"] for l in lessons] == ["109", "110", "111", "112"], "wrong lesson identities")
    lesson_ids = {l["id"] for l in lessons}
    existing_ids = set()
    # Read existing unit identities to validate prerequisites; no assembly is run.
    for path in sorted((COURSE / "content").glob("unit-*.json")):
        existing_ids.update(l["id"] for l in json.loads(path.read_text())["lessons"])
    for lesson in lessons:
        require(lesson["level"] == "Specialist electives", "wrong specialist level")
        require(type(lesson["duration"]) is int and lesson["duration"] > 0, "invalid duration")
        require(len(lesson["objectives"]) >= 3 and len(lesson["checklist"]) >= 3, "missing learning contract")
        require(set(lesson["prerequisites"]) <= existing_ids, "unknown prerequisite")
        count = teaching(lesson, 5, 1300)
        require(lesson["repo"], "missing inspected repository anchor")
        for anchor in lesson["repo"]:
            path = Path(anchor["path"])
            require(not path.is_absolute() and ".." not in path.parts
                    and path.parts[0] == "ios-client", "invalid client path")
            lines = (WORKSPACE / path).read_text().splitlines()
            require(1 <= anchor["line"] <= len(lines), "invalid repository line")
            require(lines[anchor["line"] - 1].strip() and anchor["why"].strip(), "empty anchor evidence")
        print(f"lesson {lesson['id']}: {count} prose words; sections/quiz/exercise/references/anchors PASS")

    questions = read("interview-specialists.json")["questions"]
    require(len(questions) == 8, "need eight interview prompts")
    require({q["id"] for q in questions} == {f"iq-{l}-{s}" for l in lesson_ids for s in "ab"},
            "wrong interview identities")
    for q in questions:
        require(q["lesson"] in lesson_ids and q["id"].startswith(f"iq-{q['lesson']}-"), "wrong interview lesson")
        require(q["level"] in {"Foundation", "Senior", "Staff"}, "invalid interview level")
        require(q["kind"] in {"Explain", "Debug", "Design", "Code"}, "invalid interview kind")
        require(3 <= q["minutes"] <= 20, "invalid interview duration")
        require(all(q[k].strip() for k in ["prompt", "scenario", "androidBridge"]), "missing interview context")
        require(len(q["rubric"]) >= 4 and len(q["followUps"]) >= 2 and len(q["pitfalls"]) >= 2,
                "missing observable interview feedback")
        count = words(q["answerHTML"])
        require(100 <= count <= 220, f"interview {q['id']} answer has {count} words")
        print(f"interview {q['id']}: {count} answer words; schema PASS")

    workshops = read("practice-specialists.json")["workshops"]
    require(len(workshops) == 1 and workshops[0]["id"] == "specialist-selection-lab", "wrong workshop")
    workshop = workshops[0]
    require(workshop["kind"] == "Host implementation" and set(workshop["sessions"]) == lesson_ids,
            "wrong workshop scope")
    count = teaching(workshop, 4, 900)
    paths = [f["path"] for f in workshop["files"]]
    require(set(paths) == COMPANIONS and len(paths) == len(COMPANIONS), "unbounded companion list")
    for relative in paths:
        require((COURSE / relative).is_file(), f"missing companion {relative}")
        (COURSE / relative).read_text()  # all embed artifacts must be UTF-8 text
    print(f"workshop: {count} prose words; schema and six explicit files PASS")

    # Ensure the three standalone lesson examples are the same source checked on host.
    host = (COURSE / "labs/SpecialistLab/SnippetChecks.swift").read_text()
    compact = lambda s: re.sub(r"\s+", "", unescape(s))
    for lesson in lessons[1:]:
        examples = [c for s in lesson["sections"] for c in html(s["html"]).code_blocks]
        require(len(examples) == 1, "expected one bounded Swift example")
        source = examples[0].replace("import Foundation", "").strip()
        require(compact(source) in compact(host), f"lesson {lesson['id']} differs from compiled host snippet")
    print("PASS: standalone Swift examples match companion source; global builder NOT RUN")


if __name__ == "__main__":
    main()
