import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

// Read-only check of this author's assigned content; never generates the shared site bundle.
const course = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const data = JSON.parse(fs.readFileSync(path.join(course, 'content/practice-native.json'), 'utf8'));
const expected = ['swiftui-workbench', 'ui-accessibility', 'persistence-store', 'platform-adapters'];
assert.deepEqual(data.workshops.map(w => w.id), expected);
const tags = new Set('p h3 h4 ul ol li strong em code pre table thead tbody tr th td blockquote details summary a'.split(' '));
const attrs = new Set(['class', 'href', 'title', 'scope', 'colspan', 'rowspan']);
const required = value => assert.equal(typeof value === 'string' && value.trim().length > 0, true);
function htmlCheck(html) {
    required(html);
    const stack = [];
    for (const match of html.matchAll(/<\/?([a-z][a-z0-9]*)\b(?:[^>"']|"[^"]*"|'[^']*')*>/gi)) {
        const tag = match[1].toLowerCase();
        assert(tags.has(tag), `Disallowed HTML: ${tag}`);
        if (match[0].startsWith('</')) { assert.equal(stack.pop(), tag); continue; }
        const source = match[0].slice(match[0].indexOf(match[1]) + match[1].length).replace(/\s*>$/, '');
        let parsed = '';
        for (const attr of source.matchAll(/\s+([\w-]+)\s*=\s*("[^"]*"|'[^']*')/g)) {
            parsed += attr[0];
            assert(attrs.has(attr[1]));
            if (attr[1] === 'href') assert(/^['"]https:\/\//.test(attr[2]));
        }
        assert.equal(parsed.trim(), source.trim());
        stack.push(tag);
    }
    assert.equal(stack.length, 0);
}
let anchors = 0;
let total = 0;
const connected = new Set();
for (const workshop of data.workshops) {
    required(workshop.title); required(workshop.summary);
    assert.equal(workshop.kind, 'Native implementation');
    assert(workshop.sections.length >= 4);
    assert.equal(new Set(workshop.sections.map(s => s.id)).size, workshop.sections.length);
    for (const section of workshop.sections) { assert(/^[a-z0-9-]+$/.test(section.id)); required(section.title); htmlCheck(section.html); }
    const count = (workshop.sections.map(s => s.html).join(' ') + ' ' + workshop.exercise.solution)
        .replace(/<[^>]*>/g, ' ').split(/\s+/).filter(Boolean).length;
    assert(count >= 900, `${workshop.id}: ${count} words`);
    total += count;
    required(workshop.exercise.brief); htmlCheck(workshop.exercise.solution);
    assert(workshop.exercise.steps.length >= 3 && workshop.exercise.acceptance.length >= 3);
    [...workshop.exercise.steps, ...workshop.exercise.acceptance].forEach(required);
    assert.equal(workshop.quiz.length, 3);
    for (const question of workshop.quiz) {
        required(question.question); required(question.explanation);
        assert(question.options.length >= 3); question.options.forEach(required);
        assert(Number.isInteger(question.answer) && question.answer >= 0 && question.answer < question.options.length);
    }
    assert(workshop.references.length >= 2);
    for (const reference of workshop.references) {
        required(reference.label);
        const url = new URL(reference.url);
        assert.equal(url.protocol, 'https:');
        assert.equal(url.hostname, 'developer.apple.com');
    }
    assert(workshop.sessions.length > 0);
    for (const id of workshop.sessions) {
        assert(/^\d{3}$/.test(id) && +id >= 1 && +id <= 84);
        connected.add(id);
    }
    assert(workshop.files.length > 0);
    for (const file of workshop.files) {
        required(file.label);
        assert(file.path.startsWith('labs/SwiftUIWorkbench/'));
        assert(file.path.split('/').every(segment => segment.length > 0 && !segment.startsWith('.')));
        const text = fs.readFileSync(path.join(course, file.path), 'utf8');
        assert(text.length > 0); anchors += 1;
    }
    console.log(`${workshop.id}: ${count} teaching words; sections, HTML, quiz, references and files valid`);
}
for (let id = 71; id <= 84; id++) assert(connected.has(String(id).padStart(3, '0')));
console.log(`Validated 4 native workshops, ${total} teaching words, ${anchors} file anchors, all 071–084 links`);
