"""Compile and link a simulator executable; does not package or run an app."""
import pathlib
import platform
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parent
output = pathlib.Path(tempfile.mkdtemp(prefix="architecture-native-", dir="/private/tmp"))
sdk = subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], text=True).strip()
arch = "arm64" if platform.machine() == "arm64" else "x86_64"
common = ["xcrun", "--sdk", "iphonesimulator", "swiftc", "-disable-sandbox", "-swift-version", "6", "-target", f"{arch}-apple-ios17.0-simulator",
          "-sdk", sdk, "-module-cache-path", str(output / "ModuleCache"), "-I", str(output), "-parse-as-library"]
modules = ["NoteDomain", "NoteData", "BrowseFeature", "SavedFeature", "AppShell"]
objects = []
for name in modules:
    sources = sorted((root / "Sources" / name).glob("*.swift"))
    obj = output / f"{name}.o"
    command = common + ["-module-name", name, "-emit-module", "-emit-module-path", str(output / f"{name}.swiftmodule"),
                        "-emit-object", "-whole-module-optimization"] + list(map(str, sources)) + ["-o", str(obj)]
    subprocess.run(command, check=True)
    objects.append(str(obj))
subprocess.run(common + ["-module-name", "ArchitectureApp", str(root / "Native" / "ArchitectureApp.swift")]
               + objects + ["-o", str(output / "ArchitectureApp")], check=True)
print(f"PASS: five iOS simulator modules and SwiftUI adapter compiled and linked: {output / 'ArchitectureApp'}")
subprocess.run(["xcrun", "vtool", "-show-build", str(output / "ArchitectureApp")], check=True)
print("No Xcode project build, installation, provisioning/distribution signing, simulator interaction, accessibility audit, or device run occurred.")
