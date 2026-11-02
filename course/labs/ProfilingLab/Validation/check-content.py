"""Read-only QA for this author's disjoint content; no global integration/build."""
import json
import re
from html.parser import HTMLParser
from pathlib import Path

course = Path(__file__).resolve().parents[3]
workspace = course.parents[1]
unit = json.loads((course / 'content/unit-17.json').read_text())
bank = json.loads((course / 'content/interview-profiling.json').read_text())
practice = json.loads((course / 'content/practice-profiling.json').read_text())
words = lambda text: len(re.sub(r'<[^>]+>', ' ', text).split())
allowed = set('p h3 h4 ul ol li strong em code pre table thead tbody tr th td blockquote details summary a'.split())

class SafeHTML(HTMLParser):
    def __init__(self):
        super().__init__()
        self.stack = []
    def handle_starttag(self, tag, attrs):
        assert tag in allowed, f'Unexpected tag {tag}'
        assert all(k in {'class', 'href'} for k, _ in attrs), attrs
        for k, v in attrs:
            if k == 'href': assert v.startswith('https://'), v
        self.stack.append(tag)
    def handle_endtag(self, tag):
        assert self.stack and self.stack.pop() == tag, f'Unbalanced {tag}'

def html(text):
    parser = SafeHTML(); parser.feed(text); parser.close()
    assert not parser.stack, parser.stack

def content(item, minimum, sections):
    assert len(item['sections']) >= sections and len(item['quiz']) >= 3
    assert len({s['id'] for s in item['sections']}) == len(item['sections'])
    for section in item['sections']: html(section['html'])
    html(item['exercise']['solution'])
    assert item['exercise']['steps'] and item['exercise']['acceptance']
    count = words(' '.join(s['html'] for s in item['sections']) + ' ' + item['exercise']['solution'])
    assert count >= minimum, (item['id'], count)
    for q in item['quiz']:
        assert len(q['options']) >= 3 and type(q['answer']) is int and 0 <= q['answer'] < len(q['options'])
        assert q['question'] and q['explanation']
    assert len(item['references']) >= 2
    for r in item['references']: assert r['url'].startswith('https://')
    print(item['id'], count, 'teaching words')

assert unit['unit']['id'] == 'profiling-production' and unit['unit']['order'] == 17
assert [l['id'] for l in unit['lessons']] == ['101', '102', '103', '104']
known = set()
for number in range(1, 13):
    known.update(l['id'] for l in json.loads((course / f'content/unit-{number:02}.json').read_text())['lessons'])
known.update(l['id'] for l in unit['lessons'])
for lesson in unit['lessons']:
    content(lesson, 1300, 5)
    assert all(p in known and int(p) < int(lesson['id']) for p in lesson['prerequisites'])
    assert lesson['repo'] and len(lesson['objectives']) >= 2 and len(lesson['checklist']) >= 2
    for anchor in lesson['repo']:
        assert anchor['path'].startswith('ios-client/') and '..' not in Path(anchor['path']).parts
        source = (workspace / anchor['path']).read_text().splitlines()
        assert 1 <= anchor['line'] <= len(source) and anchor['why']
        assert source[anchor['line'] - 1].strip()
assert len(bank['questions']) == 8
assert {q['id'] for q in bank['questions']} == {f'iq-{i}-{s}' for i in ['101','102','103','104'] for s in 'ab'}
for q in bank['questions']:
    assert q['lesson'] == q['id'][3:6] and q['level'] in ['Senior','Staff']
    assert q['kind'] in ['Explain','Debug','Design','Code'] and 3 <= q['minutes'] <= 20
    assert q['prompt'] and q['scenario'] and q['androidBridge']
    assert len(q['rubric']) >= 4 and len(q['followUps']) >= 2 and len(q['pitfalls']) >= 2
    html(q['answerHTML']); assert words(q['answerHTML']) >= 100
assert len(practice['workshops']) == 1
workshop = practice['workshops'][0]
assert workshop['id'] == 'profiling-evidence-lab' and workshop['sessions'] == ['101','102','103','104']
content(workshop, 900, 4)
for f in workshop['files']:
    assert f['path'].startswith('labs/ProfilingLab/')
    assert all(p and not p.startswith('.') for p in f['path'].split('/'))
    data = (course / f['path']).read_bytes(); assert b'\0' not in data and len(data) < 500_000
print('PASS: disjoint schema, safe/balanced HTML, word floors, prerequisites, quizzes, interviews, anchors and bounded companion files')
