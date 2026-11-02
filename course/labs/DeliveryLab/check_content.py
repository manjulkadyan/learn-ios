"""Audit only this author's owned content; does not build shared reader assets."""
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import urlparse


COURSE = Path(__file__).resolve().parents[2]
WORKSPACE = COURSE.parents[1]
TAGS = set("p h3 h4 ul ol li strong em code pre table thead tbody tr th td blockquote details summary a".split())
ATTRS = {"class", "href", "title", "scope", "colspan", "rowspan"}


class SafeHTML(HTMLParser):
    def handle_starttag(self, tag, attrs):
        assert tag in TAGS, ("unsafe tag", tag)
        for key, value in attrs:
            assert key in ATTRS and not key.startswith("on"), ("unsafe attribute", key)
            if key == "href":
                assert value.startswith("https://"), value

    def handle_endtag(self, tag):
        assert tag in TAGS, ("unsafe end tag", tag)

    def handle_comment(self, data):
        raise AssertionError("Unexpected HTML comment")


def teaching_words(record):
    text = " ".join(s["html"] for s in record["sections"]) + " " + record["exercise"]["solution"]
    # Stricter than the builder: count original teaching prose without code blocks.
    text = re.sub(r"<pre>[\s\S]*?</pre>", "", text)
    return len(html.unescape(re.sub(r"<[^>]+>", " ", text)).split())


def verify_html(record):
    for section in record["sections"]:
        SafeHTML().feed(section["html"])
    SafeHTML().feed(record["exercise"]["solution"])


def verify_quiz(questions):
    assert len(questions) >= 3
    for question in questions:
        assert len(question["options"]) >= 3
        assert type(question["answer"]) is int
        assert 0 <= question["answer"] < len(question["options"])
        assert question["explanation"].strip()


def verify_references(references):
    assert len(references) >= 2
    for reference in references:
        url = urlparse(reference["url"])
        assert url.scheme == "https"
        assert url.hostname in {"developer.apple.com", "docs.swift.org", "kotlinlang.org", "developer.android.com", "docs.oracle.com"}


def main():
    unit = json.loads((COURSE / "content/unit-18.json").read_text())
    assert unit["unit"]["id"] == "delivery-leadership" and unit["unit"]["order"] == 18
    assert [l["id"] for l in unit["lessons"]] == ["105", "106", "107", "108"]
    earlier = {f"{i:03}" for i in range(1, 85)}
    for lesson in unit["lessons"]:
        assert len(lesson["sections"]) >= 5
        assert lesson["prerequisites"] and all(p in earlier for p in lesson["prerequisites"])
        assert len(lesson["exercise"]["acceptance"]) >= 3
        verify_html(lesson)
        verify_quiz(lesson["quiz"])
        verify_references(lesson["references"])
        count = teaching_words(lesson)
        assert count >= 1300, (lesson["id"], count)
        assert lesson["repo"]
        for anchor in lesson["repo"]:
            path = WORKSPACE / anchor["path"]
            assert anchor["path"].startswith("ios-client/") and path.is_file()
            lines = path.read_text().splitlines()
            assert 1 <= anchor["line"] <= len(lines)
            assert lines[anchor["line"] - 1].strip(), anchor
            assert anchor["why"].strip()
        print("lesson", lesson["id"], count, "prose words; HTML, quizzes, prerequisites, references, anchors OK")
        earlier.add(lesson["id"])
    bank = json.loads((COURSE / "content/interview-delivery.json").read_text())
    expected = {f"iq-{lesson}-{suffix}" for lesson in ["105", "106", "107", "108"] for suffix in "ab"}
    assert len(bank["questions"]) == 8 and {q["id"] for q in bank["questions"]} == expected
    for q in bank["questions"]:
        assert q["lesson"] in {"105", "106", "107", "108"}
        assert q["level"] in {"Foundation", "Senior", "Staff"} and q["kind"] in {"Explain", "Debug", "Design", "Code"}
        assert 3 <= q["minutes"] <= 20
        assert len(q["rubric"]) >= 4 and len(q["followUps"]) >= 2 and len(q["pitfalls"]) >= 2
        assert q["androidBridge"].strip()
        count = len(html.unescape(re.sub(r"<[^>]+>", " ", q["answerHTML"])).split())
        assert 100 <= count <= 220, (q["id"], count)
        SafeHTML().feed(q["answerHTML"])
    print("8 interview identities, rubrics, bridges, followups, pitfalls and 100-220 word answers OK")
    bank = json.loads((COURSE / "content/practice-delivery.json").read_text())
    assert len(bank["workshops"]) == 1
    workshop = bank["workshops"][0]
    assert workshop["id"] == "delivery-review-lab" and workshop["kind"] == "Design review"
    assert workshop["sessions"] == ["105", "106", "107", "108"]
    assert len(workshop["sections"]) >= 4
    verify_html(workshop)
    verify_quiz(workshop["quiz"])
    verify_references(workshop["references"])
    count = teaching_words(workshop)
    assert count >= 900
    for file in workshop["files"]:
        path = file["path"]
        assert path.startswith("labs/DeliveryLab/")
        assert not any(part.startswith(".") for part in Path(path).parts)
        assert (COURSE / path).is_file(), path
    print("workshop", workshop["id"], count, "prose words;", len(workshop["files"]), "owned companion files OK")


if __name__ == "__main__":
    main()
