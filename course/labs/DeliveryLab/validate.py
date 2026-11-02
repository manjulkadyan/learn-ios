"""Bounded evidence consistency checks; never signs, uploads, or authorizes release."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys
import uuid


KINDS = {"host-test", "crash", "hang", "jetsam", "trace", "xcresult",
         "signed-install", "upgrade", "privacy-review", "consumer-check", "outcome-window"}


def fingerprint(record):
    """Bind review to all decision inputs, excluding the review itself."""
    body = {key: value for key, value in record.items() if key != "review"}
    return hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":"),
                                     ensure_ascii=False).encode()).hexdigest()


def artifact_digest(root, relative):
    """Reject escapes and symlinks. A directory digest binds names AND file bytes."""
    rel = PurePosixPath(relative)
    if not relative or rel.is_absolute() or ".." in rel.parts or "\\" in relative:
        raise ValueError("unsafe evidence path")
    root = Path(root).resolve(strict=True)
    current = root
    for part in rel.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError("symlink evidence is unsupported")
    path = current.resolve(strict=True)
    if not path.is_relative_to(root):
        raise ValueError("evidence escaped root")
    if path.is_file():
        return hashlib.sha256(path.read_bytes()).hexdigest()
    if not path.is_dir():
        raise ValueError("evidence is not a regular file or directory")
    entries = []
    for child in sorted(path.rglob("*")):
        if child.is_symlink():
            raise ValueError("symlink inside evidence bundle")
        if child.is_file():
            entries.append([child.relative_to(path).as_posix(),
                            hashlib.sha256(child.read_bytes()).hexdigest()])
        elif not child.is_dir():
            raise ValueError("special file inside evidence bundle")
    if not entries:
        raise ValueError("empty evidence bundle")
    return hashlib.sha256(json.dumps(entries, separators=(",", ":")).encode()).hexdigest()


def validate(record, root, mode="local"):
    errors, pending = [], []
    try:
        if record["schemaVersion"] != 1:
            raise ValueError("unsupported schemaVersion")
        artifact, expected = record["artifact"], record["expected"]
        for key in ("bundleID", "version", "build", "environment", "configuration", "sourceRevision"):
            if not isinstance(artifact[key], str) or not artifact[key].strip():
                errors.append("identity-string:" + key)
            if artifact[key] != expected[key]:
                errors.append("identity-mismatch:" + key)
        for field in ("resources", "requiredResources"):
            if not isinstance(record[field], list) or not all(isinstance(x, str) for x in record[field]):
                raise ValueError("resource lists must contain strings")
        if len(set(record["resources"])) != len(record["resources"]):
            errors.append("duplicate-resource")
        for resource in record["requiredResources"]:
            if resource not in record["resources"]:
                errors.append("missing-resource:" + resource)
        # Exact expected claims only. This is NOT Apple's full profile/wildcard matcher.
        for key, value in record["expectedEntitlements"].items():
            if record["observedEntitlements"].get(key) != value:
                errors.append("entitlement-mismatch:" + key)

        def images(rows):
            result = {}
            for row in rows:
                name, arch = row["name"], row["architecture"]
                if not all(isinstance(x, str) and x for x in (name, arch)):
                    raise ValueError("image name and architecture required")
                key = (name, arch)
                if key in result:
                    errors.append("duplicate-image:" + name + ":" + arch)
                value = uuid.UUID(row["uuid"])
                if value.int == 0:
                    errors.append("zero-image-uuid:" + name)
                result[key] = str(value)
            return result

        binary = images(artifact["binaryImages"])
        symbols = images(record["symbolImages"])
        if not binary:
            errors.append("no-binary-images")
        for key, value in binary.items():
            if symbols.get(key) != value:
                errors.append("symbol-mismatch:" + ":".join(key))

        evidence = {}
        for row in record["evidence"]:
            eid, kind = row["id"], row["kind"]
            if not isinstance(eid, str) or not eid or eid in evidence:
                errors.append("duplicate-or-empty-evidence-id")
            evidence[eid] = row
            if kind not in KINDS or row["provenance"] not in {"synthetic", "captured"}:
                errors.append("unknown-evidence-kind-or-provenance:" + str(eid))
            if row["revision"] != artifact["sourceRevision"]:
                errors.append("stale-evidence:" + eid)
            if not re.fullmatch(r"[0-9a-f]{64}", row["sha256"]):
                errors.append("malformed-digest:" + eid)
            try:
                actual = artifact_digest(root, row["path"])
                if actual != row["sha256"]:
                    errors.append("changed-evidence:" + eid)
            except (ValueError, OSError) as exc:
                errors.append("unreadable-evidence:" + eid + ":" + str(exc))

        review = record["review"]
        if review["state"] not in {"proposed", "reviewed", "revised", "retested"}:
            errors.append("unknown-review-state")
        if review["state"] != "retested":
            pending.append("review-and-retest-incomplete")
        else:
            if not review["reviewer"] or review["reviewer"] == record["author"]:
                errors.append("independent-review-required")
            if review["reviewedFingerprint"] != fingerprint(record):
                errors.append("review-stale")
            if not review["revisionNote"].strip():
                errors.append("revision-note-required")
            for finding in review["findings"]:
                if finding["severity"] not in {"blocking", "advisory"} or finding["status"] not in {"open", "resolved", "accepted"}:
                    errors.append("invalid-finding-state")
                if finding["severity"] == "blocking" and finding["status"] != "resolved":
                    pending.append("blocking-finding:" + finding["id"])
                if finding["status"] != "open" and not finding["resolution"].strip():
                    errors.append("finding-resolution-required:" + finding["id"])
            if not any(e["kind"] == "host-test" for e in evidence.values()):
                pending.append("host-retest-evidence-required")

        required = {
            "local": set(),
            "installation": {"signed-install", "upgrade", "privacy-review"},
            "diagnostic": {record.get("diagnosticKind", "crash")},
            "deprecation": {"consumer-check", "outcome-window"},
        }[mode]
        if mode == "diagnostic" and record.get("diagnosticKind") not in {"crash", "hang", "jetsam", "trace", "xcresult"}:
            errors.append("unsupported-diagnostic-kind")
        # A captured declaration is supplied by the learner, not authenticated by this tool.
        captured = {e["kind"] for e in evidence.values() if e["provenance"] == "captured"}
        for kind in sorted(required - captured):
            pending.append("missing-captured:" + kind)
        if mode == "installation":
            for key in ("effectiveSettingsChecked", "signatureChecked", "profileChecked", "packagingChecked"):
                if record.get(key) is not True:
                    pending.append("manual-check-required:" + key)
        if mode == "deprecation":
            consumers = record["consumers"]
            ids = [c["id"] for c in consumers]
            if not ids or len(set(ids)) != len(ids):
                errors.append("consumer-denominator-invalid")
            for consumer in consumers:
                cid = consumer["id"]
                if not consumer["owner"] or not consumer["decisionRight"]:
                    errors.append("consumer-owner-required:" + cid)
                if consumer["state"] == "exception":
                    exception = consumer["exception"]
                    if not all(exception.get(k) for k in ("owner", "reason", "reviewDate", "compensatingCheck")):
                        errors.append("exception-contract-incomplete:" + cid)
                    pending.append("exception-prevents-removal:" + cid)
                elif consumer["state"] == "adopted":
                    item = evidence.get(consumer["evidenceID"], {})
                    if item.get("kind") != "consumer-check" or item.get("provenance") != "captured":
                        pending.append("consumer-proof-required:" + cid)
                elif consumer["state"] == "pending":
                    pending.append("consumer-not-adopted:" + cid)
                else:
                    errors.append("consumer-state-invalid:" + cid)
            if record.get("installedCompatibilityOwner", "") == "":
                errors.append("installed-compatibility-owner-required")
    except (KeyError, TypeError, ValueError, AttributeError) as exc:
        errors.append("malformed-record:" + str(exc))
    return {"status": "invalid" if errors else "pending" if pending else "consistent",
            "scope": mode, "errors": sorted(set(errors)), "pending": sorted(set(pending)),
            "limit": "Consistency only; provenance, signature, review identity, runtime health and adoption are not authenticated."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record")
    parser.add_argument("--root", required=True, help="Evidence root; paths in record are relative to it")
    parser.add_argument("--mode", choices=("local", "installation", "diagnostic", "deprecation"), default="local")
    args = parser.parse_args()
    try:
        record = json.loads(Path(args.record).read_text())
        result = validate(record, args.root, args.mode)
    except (OSError, json.JSONDecodeError) as exc:
        result = {"status": "invalid", "errors": [str(exc)], "pending": []}
    print(json.dumps(result, indent=2))
    return {"consistent": 0, "invalid": 1, "pending": 2}[result["status"]]


if __name__ == "__main__":
    sys.exit(main())
