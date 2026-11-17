"""Check lesson 138's actual snippets in a temporary, offline package consumer."""
from html.parser import HTMLParser
from pathlib import Path
import json
import os
import shlex
import shutil
import subprocess
import tempfile


class SwiftSnippets(HTMLParser):
    def __init__(self):
        super().__init__()
        self.blocks = []
        self.current = None

    def handle_starttag(self, tag, attrs):
        if tag == 'code' and dict(attrs).get('class') == 'language-swift':
            self.current = []

    def handle_data(self, data):
        if self.current is not None:
            self.current.append(data)

    def handle_endtag(self, tag):
        if tag == 'code' and self.current is not None:
            self.blocks.append(''.join(self.current))
            self.current = None


task_root = Path(__file__).resolve().parent
lessons = json.loads((task_root.parents[1] / 'content/unit-25.json').read_text())['lessons']
lesson = next(item for item in lessons if item['id'] == '138')
section = next(item for item in lesson['sections'] if item['id'] == 'api-change')
snippets = SwiftSnippets()
snippets.feed(section['html'])
helper = next(block for block in snippets.blocks if 'private func resourceDebugLabel' in block)
attempt = next(block for block in snippets.blocks if 'print(catalog.resourceDebugLabel())' in block)

subprocess.run(['swift', '--version'], check=True)
with tempfile.TemporaryDirectory(prefix='ios-learning-private-access-', dir='/private/tmp') as temporary:
    task_output = Path(temporary)
    scratch_package = task_output / 'PackageProject'
    shutil.copytree(task_root, scratch_package, ignore=shutil.ignore_patterns('.build', '.swiftpm'))
    catalog = scratch_package / 'Sources/WorkshopKit/Catalog.swift'
    catalog.write_text(catalog.read_text() + '\n' + helper + '\n')
    consumer = scratch_package / 'Consumer/Sources/CatalogConsumer/main.swift'
    environment = dict(os.environ,
                       CLANG_MODULE_CACHE_PATH=str(task_output / 'modules'),
                       SWIFTPM_MODULECACHE_OVERRIDE=str(task_output / 'modules'))
    command = ['swift', 'build', '--disable-sandbox',
               '--package-path', str(scratch_package / 'Consumer'),
               '--scratch-path', str(task_output / 'build'),
               '--cache-path', str(task_output / 'cache')]
    print(shlex.join(command), flush=True)
    control = subprocess.run(command, env=environment, text=True, capture_output=True)
    if control.returncode != 0:
        raise SystemExit(control.stdout + control.stderr)
    print('Public consumer control: exit 0 with the private helper present.', flush=True)

    consumer.write_text(consumer.read_text() + '\n' + attempt + '\n')
    print(shlex.join(command), flush=True)
    rejected = subprocess.run(command, env=environment, text=True, capture_output=True)
    diagnostic = "'resourceDebugLabel' is inaccessible due to 'private' protection level"
    output = rejected.stdout + rejected.stderr
    if rejected.returncode == 0 or diagnostic not in output:
        raise SystemExit('Expected a private-access rejection; received:\n' + output)
    print('Private consumer attempt: expected exit ' + str(rejected.returncode) + '.', flush=True)
    for line in output.splitlines():
        if diagnostic in line or 'declared here' in line:
            print(line)

print('Lesson 138 private-access diagnostic passed; only the temporary copy was changed.')
