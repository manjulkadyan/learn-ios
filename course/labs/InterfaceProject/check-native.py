"""Typecheck isolated iOS source; no app assembly, launch, or interaction."""
from pathlib import Path
import shlex
import subprocess

task_root = Path(__file__).resolve().parent
task_output = Path('/private/tmp/ios-learning-interface-native')
task_output.mkdir(exist_ok=True)
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
base = ['xcrun', 'swiftc', '-disable-sandbox', '-swift-version', '6', '-sdk', sdk,
        '-target', 'arm64-apple-ios17.0-simulator', '-module-cache-path', str(task_output / 'modules'),
        '-parse-as-library']
commands = [
    base + ['-emit-module', '-module-name', 'InterfaceCore', str(task_root / 'Sources/InterfaceCore/Board.swift'),
            '-emit-module-path', str(task_output / 'InterfaceCore.swiftmodule')],
    base + ['-typecheck', '-I', str(task_output), str(task_root / 'Native/InterfaceApp.swift')],
]
for command in commands:
    print(shlex.join(command), flush=True)
    subprocess.run(command, check=True)
print('Interface native source check passed; app assembly, interaction, and profiling remain pending.')
