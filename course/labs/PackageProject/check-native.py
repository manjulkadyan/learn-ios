"""Native source check; deliberately does not assemble an iOS resource bundle."""
from pathlib import Path
import shlex
import subprocess

task_root = Path(__file__).resolve().parent
task_output = Path('/private/tmp/ios-learning-package-native')
task_output.mkdir(exist_ok=True)
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
base = ['xcrun', 'swiftc', '-disable-sandbox', '-swift-version', '6', '-sdk', sdk,
        '-target', 'arm64-apple-ios17.0-simulator', '-module-cache-path', str(task_output / 'modules'),
        '-parse-as-library']
accessors = list(Path('/private/tmp/ios-learning-package-build').rglob('resource_bundle_accessor.swift'))
if len(accessors) != 1:
    raise SystemExit('Run verify-host.sh first; expected one generated resource accessor.')
commands = [
    base + ['-emit-module', '-module-name', 'WorkshopKit',
            str(task_root / 'Sources/WorkshopKit/Catalog.swift'), str(accessors[0]),
            '-emit-module-path', str(task_output / 'WorkshopKit.swiftmodule')],
    base + ['-typecheck', '-I', str(task_output), str(task_root / 'Native/PackageCard.swift'),
            str(task_root / 'Native/PackageDemoApp.swift')],
]
for command in commands:
    print(shlex.join(command), flush=True)
    subprocess.run(command, check=True)
print('Package native source check passed; iOS resource packaging and runtime load remain pending.')
