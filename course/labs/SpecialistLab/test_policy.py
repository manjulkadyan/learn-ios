"""Adversarial correctness checks against declared product invariants."""
from dataclasses import replace
import itertools
import unittest

from policy_model import (ConflictStore, EntitlementLedger, FeatureInputs, Record,
                          Surface, Transaction, feature_plan, merge_fields,
                          surface_status, update_surface)


class TransactionChecks(unittest.TestCase):
    def test_unverified_and_stale_inputs_cannot_grant(self):
        ledger = EntitlementLedger()
        self.assertEqual(ledger.apply(1, Transaction("a", "pro", 1, False)), "unverified")
        ledger.rotate_owner()
        self.assertEqual(ledger.apply(1, Transaction("a", "pro", 2, True)), "stale-owner")
        self.assertFalse(ledger.grants("pro", 0))

    def test_revoke_wins_every_fixture_delivery_permutation(self):
        events = [Transaction("a", "pro", 1, True, 100),
                  Transaction("a", "pro", 2, True, 100, 40)]
        for order in itertools.permutations(events + [events[0]]):
            ledger = EntitlementLedger()
            for event in order:
                ledger.apply(1, event)
            self.assertFalse(ledger.grants("pro", 50))

    def test_expiry_boundary_and_new_renewal_are_independent(self):
        ledger = EntitlementLedger()
        ledger.apply(1, Transaction("a", "pro", 1, True, 100, 40))
        ledger.apply(1, Transaction("b", "pro", 1, True, 200))
        self.assertTrue(ledger.grants("pro", 199))
        self.assertFalse(ledger.grants("pro", 200))

    def test_restart_and_conflicting_same_revision(self):
        ledger = EntitlementLedger()
        t = Transaction("a", "pro", 1, True, 100)
        ledger.apply(1, t)
        restored = EntitlementLedger.restore(ledger.snapshot())
        self.assertEqual(restored.apply(1, t), "duplicate")
        self.assertEqual(restored.apply(1, replace(t, revoked_at=20)), "revision-conflict")
        self.assertEqual(restored.apply(1, replace(t, product="other")), "identity-mismatch")
        self.assertTrue(restored.grants("pro", 90))


class ConflictChecks(unittest.TestCase):
    def test_disjoint_changes_preserve_both_sides_without_mutation(self):
        base = {"title": "Draft", "note": "Blue"}
        local = {"title": "A", "note": "Blue"}
        remote = {"title": "Draft", "note": "Green"}
        self.assertEqual(merge_fields(base, local, remote),
                         ({"title": "A", "note": "Green"}, ()))
        self.assertEqual(base["title"], "Draft")
        self.assertEqual(remote["title"], "Draft")

    def test_same_field_disagreement_does_not_silently_overwrite(self):
        merged, conflicts = merge_fields({"title": "Draft"}, {"title": "A"}, {"title": "B"})
        self.assertEqual(merged, {"title": "B"})
        self.assertEqual(conflicts, ("title",))
        self.assertEqual(merge_fields({"title": "D"}, {"title": "A"}, {"title": "A"}),
                         ({"title": "A"}, ()))
        with self.assertRaises(ValueError):
            merge_fields({"x": 1}, {}, {"x": 1})

    def test_lost_ack_retry_survives_model_reconstruction(self):
        store = ConflictStore(Record(7, "Draft", "Blue"))
        proposal = Record(7, "A", "Blue")
        self.assertEqual(store.save(1, "op-1", 7, proposal), "saved")
        restored = ConflictStore.restore(store.snapshot())
        self.assertEqual(restored.save(1, "op-1", 7, proposal), "duplicate")
        self.assertEqual(restored.record.tag, 8)
        self.assertEqual(restored.save(1, "op-1", 8, replace(proposal, title="B")),
                         "operation-id-reused")

    def test_stale_tag_and_old_account_do_not_mutate(self):
        store = ConflictStore(Record(8, "Remote", "Blue"))
        before = store.snapshot()
        self.assertEqual(store.save(1, "op-2", 7, Record(7, "Local", "Blue")),
                         "server-record-changed")
        self.assertEqual(store.snapshot(), before)
        store.rotate_owner(Record(1, "New", "Green"))
        self.assertEqual(store.save(1, "op-2", 1, Record(1, "Old", "Blue")), "stale-owner")
        self.assertEqual(store.record.title, "New")


class LifecycleChecks(unittest.TestCase):
    def test_freshness_and_lifetime_boundaries_differ(self):
        s = Surface(1, 3, "queued", 20, 80)
        self.assertEqual([surface_status(s, n) for n in [19, 20, 79, 80]],
                         ["fresh", "stale", "stale", "ended"])
        s, outcome = update_surface(s, 1, 4, "ready", 50, 21)
        self.assertEqual(outcome, "updated")
        self.assertEqual(surface_status(s, 21), "fresh")

    def test_obsolete_wrong_owner_and_late_updates_cannot_resurrect(self):
        s = Surface(2, 3, "queued", 20, 80)
        for args, expected in [((2, 2, "old", 50, 21), "obsolete"),
                               ((1, 4, "old-owner", 50, 21), "stale-owner"),
                               ((2, 4, "late", 90, 80), "ended")]:
            updated, result = update_surface(s, *args)
            self.assertEqual((updated, result), (s, expected))
        ended = replace(s, ended=True)
        self.assertEqual(update_surface(ended, 2, 4, "late", 50, 10), (ended, "ended"))


class SelectionChecks(unittest.TestCase):
    def test_health_empty_is_not_read_denied(self):
        s = FeatureInputs(True, True, True, True)
        self.assertEqual(feature_plan("health", s), "no-visible-data")
        self.assertEqual(feature_plan("health", replace(s, read_visibility="samples")),
                         "show-observed-data")

    def test_fallbacks_and_transport_semantics(self):
        s = FeatureInputs(True, True, True, False)
        self.assertEqual(feature_plan("watch", s), "queue-idempotent-command")
        self.assertEqual(feature_plan("bluetooth", s), "manual-fallback")
        self.assertEqual(feature_plan("vision", replace(s, foreground=False)), "pause-spatial-work")
        self.assertEqual(feature_plan("health", replace(s, consent=False)), "explain-opt-in")
        for branch in ["watch", "vision", "bluetooth", "health"]:
            self.assertEqual(feature_plan(branch, replace(s, available=False)), "manual-fallback")
        with self.assertRaises(ValueError):
            feature_plan("unsupported", s)


if __name__ == "__main__":
    unittest.main(verbosity=2)
