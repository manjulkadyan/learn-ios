#!/usr/bin/env python3
"""Actual local Git operations; every Git cwd is a new /private/tmp repository."""
from pathlib import Path
import json
import os
import subprocess
import tempfile

ROOT = Path(tempfile.mkdtemp(prefix="git-project-", dir="/private/tmp")).resolve()
ENV = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
ENV.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null",
           GIT_CONFIG_SYSTEM="/dev/null", GIT_TERMINAL_PROMPT="0", GIT_ATTR_NOSYSTEM="1")
REPORT = []


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def git(repo, *args, ok=(0,)):
    repo = repo.resolve()
    require(repo.is_relative_to(ROOT), "Git must stay inside this run's unique scratch directory")
    command = ["git", "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgsign=false",
               "-c", "tag.gpgsign=false", "-c", "core.autocrlf=false",
               "-c", "user.name=Scratch Learner", "-c", "user.email=learner@example.invalid",
               "-C", str(repo), *args]
    result = subprocess.run(command, env=ENV, text=True, capture_output=True, timeout=30)
    require(result.returncode in ok, f"git {' '.join(args)}: {result.returncode}\n{result.stderr}\n{result.stdout}")
    return result.stdout.strip()


def write(repo, name, contents):
    path = repo / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(contents)


def create_repo(name):
    repo = ROOT / name
    repo.mkdir()
    git(repo, "init", "--initial-branch=main")
    return repo


def commit(repo, message):
    git(repo, "commit", "-m", message)
    return git(repo, "rev-parse", "HEAD")


def check(label, evidence):
    REPORT.append({"check": label, "evidence": evidence})
    print(f"PASS {label}")


def staging_and_ignores():
    repo = create_repo("staging")
    write(repo, ".gitignore", ".build/\nDerivedData/\nxcuserdata/\n*.xcuserstate\n")
    write(repo, "Tasks.txt", "Pack bag: incomplete\n")
    git(repo, "add", ".gitignore", "Tasks.txt")
    initial = commit(repo, "Record one incomplete task and generated-file policy")
    write(repo, "Tasks.txt", "Pack bag: complete\n")
    git(repo, "add", "Tasks.txt")
    write(repo, "Tasks.txt", "Pack blue bag: complete\n")
    staged = git(repo, "diff", "--cached", "--", "Tasks.txt")
    unstaged = git(repo, "diff", "--", "Tasks.txt")
    require("+Pack bag: complete" in staged, "index captured earlier content")
    require("+Pack blue bag: complete" in unstaged, "working file has later content")
    require(git(repo, "status", "--short", "--", "Tasks.txt").startswith("MM"), "both boundaries modified")
    completion = commit(repo, "Complete the existing task without renaming it")
    require(git(repo, "show", "HEAD:Tasks.txt") == "Pack bag: complete", "commit comes from index")
    require((repo / "Tasks.txt").read_text() == "Pack blue bag: complete\n", "unstaged rename survives")
    git(repo, "restore", "--", "Tasks.txt")  # Deliberate discard ONLY of this known synthetic rename.
    write(repo, ".build/cache.txt", "generated")
    write(repo, "DerivedData/output.txt", "generated")
    write(repo, "xcuserdata/window.xcuserstate", "personal")
    for name in [".build/cache.txt", "DerivedData/output.txt", "xcuserdata/window.xcuserstate"]:
        git(repo, "check-ignore", "-q", name)
    write(repo, "Resources/Theme.json", '{"accent":"blue"}\n')
    write(repo, "Package.resolved", '{"pins":[],"version":3}\n')
    git(repo, "add", "Resources/Theme.json", "Package.resolved")
    commit(repo, "Track a synthetic resource and empty application resolution fixture")
    require(git(repo, "ls-files", "Resources/Theme.json", "Package.resolved").splitlines() == ["Package.resolved", "Resources/Theme.json"], "required inputs tracked")
    write(repo, ".gitignore", (repo / ".gitignore").read_text() + "Tasks.txt\n")
    write(repo, "Tasks.txt", "Tracked even after ignore\n")
    require("Tasks.txt" in git(repo, "diff", "--name-only"), "ignores do not untrack existing files")
    check("staged snapshot, independent working copy, ignores and tracked inputs", {"initial": initial, "completion": completion, "stagedDiff": staged, "unstagedDiff": unstaged})


def branch_conflict():
    repo = create_repo("conflict")
    write(repo, "TaskPolicy.txt", "limit=80\n")
    git(repo, "add", "TaskPolicy.txt")
    base = commit(repo, "Define the initial task title limit")
    git(repo, "switch", "-c", "feature/longer-title")
    write(repo, "TaskPolicy.txt", "limit=100\n")
    git(repo, "add", "TaskPolicy.txt")
    feature = commit(repo, "Allow a longer title in the feature experiment")
    git(repo, "switch", "main")
    write(repo, "TaskPolicy.txt", "limit=60\n")
    git(repo, "add", "TaskPolicy.txt")
    main = commit(repo, "Choose a shorter title on the main experiment")
    git(repo, "merge", "--no-edit", "feature/longer-title", ok=(1,))
    conflict = (repo / "TaskPolicy.txt").read_text()
    require("<<<<<<<" in conflict and "=======" in conflict, "deliberate conflict markers")
    require(len(git(repo, "ls-files", "-u", "--", "TaskPolicy.txt").splitlines()) == 3, "base/ours/theirs index stages")
    git(repo, "merge", "--abort")
    require(git(repo, "rev-parse", "HEAD") == main and (repo / "TaskPolicy.txt").read_text() == "limit=60\n", "abort returns to pre-merge main")
    git(repo, "merge", "--no-edit", "feature/longer-title", ok=(1,))
    write(repo, "TaskPolicy.txt", "limit=80\n")  # Explicit teaching decision, not automatic ours/theirs.
    git(repo, "add", "TaskPolicy.txt")
    require(git(repo, "ls-files", "-u") == "", "resolution stages cleared")
    merged = commit(repo, "Resolve the limit experiments to the agreed value 80")
    parents = git(repo, "rev-list", "--parents", "-n", "1", "HEAD").split()[1:]
    require(parents == [main, feature], "merge has both parents")
    require(git(repo, "status", "--porcelain") == "", "resolved tree clean")
    check("divergent branches, conflict index, abort and intentional merge", {"base": base, "parents": parents, "merge": merged, "conflict": conflict})


def recovery():
    repo = create_repo("recovery")
    write(repo, "TaskPolicy.txt", "limit=80\n")
    git(repo, "add", "TaskPolicy.txt")
    baseline = commit(repo, "Keep the agreed title limit")
    write(repo, "TaskPolicy.txt", "limit=8\n")
    git(repo, "add", "TaskPolicy.txt")
    bad = commit(repo, "Introduce a deliberately wrong limit for recovery practice")
    git(repo, "revert", "--no-edit", bad)
    require((repo / "TaskPolicy.txt").read_text() == "limit=80\n", "revert restores behavior")
    require(git(repo, "merge-base", "--is-ancestor", bad, "HEAD") == "", "bad commit remains in ancestry")
    reverted = git(repo, "rev-parse", "HEAD")
    write(repo, "Notes.txt", "Private experiment\n")
    git(repo, "add", "Notes.txt")
    private = commit(repo, "Add private experiment notes")
    git(repo, "branch", "rescue/private-notes", private)
    git(repo, "reset", "--soft", "HEAD~1")
    require(git(repo, "rev-parse", "HEAD") == reverted, "soft moves HEAD")
    require("Notes.txt" in git(repo, "diff", "--cached", "--name-only"), "soft retains staged changes")
    git(repo, "reset", "--mixed", "HEAD")
    require(git(repo, "diff", "--cached", "--name-only") == "", "mixed clears index difference")
    require((repo / "Notes.txt").exists() and "?? Notes.txt" in git(repo, "status", "--short"), "untracked new file remains")
    require(private in git(repo, "reflog", "--format=%H"), "local reflog includes abandoned tip")
    require(git(repo, "show", "rescue/private-notes:Notes.txt") == "Private experiment", "named rescue retains content")
    git(repo, "restore", "--source=rescue/private-notes", "--staged", "--worktree", "--", "Notes.txt")
    commit(repo, "Recover the selected notes through a new commit")
    write(repo, "TaskPolicy.txt", "throwaway working edit\n")
    git(repo, "reset", "--hard", "HEAD")  # Known disposable tracked edit, inside ROOT only.
    require((repo / "TaskPolicy.txt").read_text() == "limit=80\n", "hard discards known tracked scratch edit")
    check("revert ancestry, soft/mixed reset, rescue ref and bounded hard reset", {"baseline": baseline, "bad": bad, "revert": reverted, "rescued": private})


def rebase_and_review():
    repo = create_repo("review")
    fixture = Path(__file__).resolve().parent / "Fixtures"
    for name in ["App.swift", "Resources/Theme.json", "TargetResources.txt"]:
        write(repo, name, (fixture / name).read_text())
    git(repo, "add", "App.swift", "Resources/Theme.json", "TargetResources.txt")
    base = commit(repo, "Record source and explicit resource-review fixtures")
    git(repo, "switch", "-c", "feature/theme")
    write(repo, "Resources/Theme.json", '{"accent":"orange"}\n')
    git(repo, "add", "Resources/Theme.json")
    first = commit(repo, "Change the synthetic theme resource to orange")
    write(repo, "Review.md", "Verify resource ownership in an actual isolated Xcode target; runtime pending.\n")
    git(repo, "add", "Review.md")
    second = commit(repo, "Record the remaining native resource check")
    git(repo, "branch", "rescue/before-rebase")
    git(repo, "switch", "main")
    write(repo, "BuildPolicy.md", "Use an isolated target; keep personal settings untracked.\n")
    git(repo, "add", "BuildPolicy.md")
    main = commit(repo, "Document independent build ownership")
    git(repo, "switch", "feature/theme")
    git(repo, "rebase", "main")
    require(git(repo, "rev-parse", "HEAD") != second, "rebase creates new tip")
    git(repo, "merge-base", "--is-ancestor", main, "HEAD")
    review_names = git(repo, "diff", "--name-only", "main...HEAD").splitlines()
    require(review_names == ["Resources/Theme.json", "Review.md"], "review excludes independent main change")
    require(json.loads((repo / "Resources/Theme.json").read_text())["accent"] == "orange", "replayed behavior remains")
    ranges = git(repo, "range-diff", f"{base}..rescue/before-rebase", "main..HEAD")
    require("Change the synthetic theme" in ranges and "Record the remaining native" in ranges, "review replayed patch series")
    tracked = set(git(repo, "ls-files").splitlines())
    for resource in (repo / "TargetResources.txt").read_text().splitlines():
        require(resource in tracked and (repo / resource).is_file(), "fixture membership input exists and is tracked")
    require(git(repo, "remote") == "", "no remotes configured")
    check("private rebase, merge-base review, range-diff and resource inputs", {"oldCommits": [first, second], "newTip": git(repo, "rev-parse", "HEAD"), "reviewPaths": review_names, "rangeDiff": ranges})


if __name__ == "__main__":
    print(f"Scratch root: {ROOT}")
    print(subprocess.run(["git", "--version"], text=True, capture_output=True, check=True).stdout.strip())
    staging_and_ignores()
    branch_conflict()
    recovery()
    rebase_and_review()
    report = ROOT / "evidence.json"
    report.write_text(json.dumps({"scope": "local disposable Git only; no Xcode build or remote PR", "checks": REPORT}, indent=2) + "\n")
    print(f"PASS 4 Git behavior groups; evidence: {report}")
