import copy
import json
from pathlib import Path
import tempfile
import unittest
from validate import artifact_digest, fingerprint, validate


LAB = Path(__file__).resolve().parent


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="deliverylab-test-", dir="/private/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "fixtures").mkdir()
        (self.root / "fixtures/synthetic-result.txt").write_bytes((LAB / "fixtures/synthetic-result.txt").read_bytes())
        self.record = json.loads((LAB / "fixtures/pending.json").read_text())

    def check(self, mode="local"):
        return validate(self.record, self.root, mode)

    def retested(self):
        self.record["review"].update(state="retested", reviewer="synthetic-independent-peer",
                                     revisionNote="Fixture: add missing architecture check")
        self.record["review"]["reviewedFingerprint"] = fingerprint(self.record)

    def test_proposal_is_pending(self):
        self.assertEqual(self.check()["status"], "pending")

    def test_retested_synthetic_local_consistency(self):
        self.retested()
        self.assertEqual(self.check()["status"], "consistent")

    def test_numeric_build_rejected(self):
        self.record["artifact"]["build"] = 42
        self.assertIn("identity-string:build", self.check()["errors"])

    def test_wrong_environment(self):
        self.record["artifact"]["environment"] = "production"
        self.assertIn("identity-mismatch:environment", self.check()["errors"])

    def test_missing_resource(self):
        self.record["resources"].remove("PrivacyInfo.xcprivacy")
        self.assertIn("missing-resource:PrivacyInfo.xcprivacy", self.check()["errors"])

    def test_wrong_entitlement(self):
        self.record["observedEntitlements"]["aps-environment"] = "production"
        self.assertIn("entitlement-mismatch:aps-environment", self.check()["errors"])

    def test_same_version_wrong_uuid(self):
        self.record["symbolImages"][0]["uuid"] = "22222222-2222-4222-8222-222222222222"
        self.assertIn("symbol-mismatch:Scratch:arm64", self.check()["errors"])

    def test_architecture_must_match(self):
        self.record["symbolImages"][0]["architecture"] = "x86_64"
        self.assertIn("symbol-mismatch:Scratch:arm64", self.check()["errors"])

    def test_duplicate_image(self):
        self.record["symbolImages"].append(copy.deepcopy(self.record["symbolImages"][0]))
        self.assertTrue(any(e.startswith("duplicate-image:") for e in self.check()["errors"]))

    def test_uuid_normalization(self):
        self.record["symbolImages"][0]["uuid"] = self.record["symbolImages"][0]["uuid"].upper()
        self.assertEqual(self.check()["errors"], [])

    def test_review_changes_after_evidence_edit(self):
        self.retested()
        self.record["consumers"][0]["owner"] = "new-owner"
        self.assertIn("review-stale", self.check()["errors"])

    def test_same_author_is_not_independent(self):
        self.retested()
        self.record["review"]["reviewer"] = self.record["author"]
        self.assertIn("independent-review-required", self.check()["errors"])

    def test_blocker_acceptance_does_not_close_it(self):
        self.retested()
        self.record["review"]["findings"] = [{"id": "f1", "severity": "blocking", "status": "accepted", "resolution": "Deadline pressure"}]
        self.assertIn("blocking-finding:f1", self.check()["pending"])

    def test_stale_retest(self):
        self.record["evidence"][0]["revision"] = "old-source"
        self.assertIn("stale-evidence:fixture-tests", self.check()["errors"])

    def test_changed_bytes(self):
        (self.root / "fixtures/synthetic-result.txt").write_text("changed")
        self.assertIn("changed-evidence:fixture-tests", self.check()["errors"])

    def test_missing_file(self):
        (self.root / "fixtures/synthetic-result.txt").unlink()
        self.assertTrue(any(e.startswith("unreadable-evidence:") for e in self.check()["errors"]))

    def test_traversal_rejected(self):
        self.record["evidence"][0]["path"] = "../outside.txt"
        self.assertTrue(any("unsafe evidence path" in e for e in self.check()["errors"]))

    def test_symlink_rejected(self):
        (self.root / "shortcut").symlink_to(self.root / "fixtures", target_is_directory=True)
        self.record["evidence"][0]["path"] = "shortcut/synthetic-result.txt"
        self.assertTrue(any("symlink" in e for e in self.check()["errors"]))

    def test_directory_digest_binds_names(self):
        bundle = self.root / "synthetic.xcresult"
        bundle.mkdir()
        (bundle / "a").write_text("synthetic, not an Xcode result")
        before = artifact_digest(self.root, "synthetic.xcresult")
        (bundle / "a").rename(bundle / "b")
        self.assertNotEqual(before, artifact_digest(self.root, "synthetic.xcresult"))

    def test_synthetic_cannot_satisfy_installation(self):
        self.retested()
        result = self.check("installation")
        self.assertEqual(result["status"], "pending")
        self.assertIn("missing-captured:upgrade", result["pending"])

    def test_synthetic_cannot_satisfy_diagnostics(self):
        self.record["diagnosticKind"] = "xcresult"
        self.assertIn("missing-captured:xcresult", self.check("diagnostic")["pending"])

    def test_exception_blocks_retirement(self):
        self.record["consumers"][0].update(state="exception", exception={"owner": "synthetic-extension-owner", "reason": "Interprocess store", "reviewDate": "2027-01-10", "compensatingCheck": "Keep compatible baseline"})
        self.assertIn("exception-prevents-removal:extension", self.check("deprecation")["pending"])

    def test_dependency_presence_does_not_prove_adoption(self):
        self.record["consumers"][0].update(state="adopted", evidenceID="fixture-tests")
        self.assertIn("consumer-proof-required:extension", self.check("deprecation")["pending"])

    def test_empty_denominator_rejected(self):
        self.record["consumers"] = []
        self.assertIn("consumer-denominator-invalid", self.check("deprecation")["errors"])

    def test_unknown_schema(self):
        self.record["schemaVersion"] = 2
        self.assertEqual(self.check()["status"], "invalid")


if __name__ == "__main__":
    unittest.main()
