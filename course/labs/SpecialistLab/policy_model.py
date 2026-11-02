"""Synthetic policy model. No Apple frameworks, requests, credentials or permissions.

Requires Python 3.11+. Revisions, tags and clock values are fixture conventions,
not a simulation of StoreKit ordering, CloudKit delivery, or ActivityKit scheduling.
"""
from dataclasses import asdict, dataclass, replace
import json


@dataclass(frozen=True)
class Transaction:
    transaction_id: str
    product: str
    revision: int
    verified: bool
    expires_at: int | None = None
    revoked_at: int | None = None


class EntitlementLedger:
    """One synthetic account generation; trusted verification is an injected input."""

    def __init__(self, epoch=1):
        self.epoch = epoch
        self.records: dict[str, Transaction] = {}

    def apply(self, epoch: int, event: Transaction) -> str:
        if epoch != self.epoch:
            return "stale-owner"
        if not event.verified:
            return "unverified"
        old = self.records.get(event.transaction_id)
        if old and event.product != old.product:
            return "identity-mismatch"
        if old and event.revision < old.revision:
            return "obsolete"
        if old and event.revision == old.revision:
            return "duplicate" if old == event else "revision-conflict"
        self.records[event.transaction_id] = event
        return "applied"

    def grants(self, product: str, now: int) -> bool:
        return any(
            t.product == product and t.revoked_at is None
            and (t.expires_at is None or now < t.expires_at)
            for t in self.records.values()
        )

    def rotate_owner(self) -> None:
        self.epoch += 1
        self.records.clear()

    def snapshot(self) -> str:
        return json.dumps({"epoch": self.epoch,
                           "records": [asdict(t) for t in self.records.values()]})

    @classmethod
    def restore(cls, encoded: str):
        data = json.loads(encoded)
        ledger = cls(data["epoch"])
        for row in data["records"]:
            ledger.apply(ledger.epoch, Transaction(**row))
        return ledger


def merge_fields(base: dict, local: dict, server: dict) -> tuple[dict, tuple[str, ...]]:
    """Three-way field merge. Same-field disagreement preserves server + conflict.

    Inputs must have identical field sets; deletion/tombstones are a later exercise.
    """
    if base.keys() != local.keys() or base.keys() != server.keys():
        raise ValueError("fixed-schema fixture requires identical keys")
    merged = dict(server)
    conflicts = []
    for key in sorted(base):
        local_changed = local[key] != base[key]
        server_changed = server[key] != base[key]
        if local_changed and server_changed and local[key] != server[key]:
            conflicts.append(key)
        elif local_changed:
            merged[key] = local[key]
    return merged, tuple(conflicts)


@dataclass(frozen=True)
class Record:
    tag: int
    title: str
    note: str


class ConflictStore:
    """Synthetic conditional save + idempotent operation receipt, one writer.

    export/restore is JSON model reconstruction, not a disk durability test.
    A real implementation needs atomic effect-and-receipt persistence.
    """

    def __init__(self, record: Record, epoch=1):
        self.record = record
        self.epoch = epoch
        self.receipts: dict[str, tuple[Record, int]] = {}

    def save(self, epoch: int, operation_id: str, expected_tag: int,
             proposed: Record) -> str:
        if epoch != self.epoch:
            return "stale-owner"
        prior = self.receipts.get(operation_id)
        if prior:
            return "duplicate" if prior[0] == proposed else "operation-id-reused"
        if expected_tag != self.record.tag:
            return "server-record-changed"
        self.record = replace(proposed, tag=self.record.tag + 1)
        self.receipts[operation_id] = (proposed, self.record.tag)
        return "saved"

    def rotate_owner(self, record: Record) -> None:
        self.epoch += 1
        self.record = record
        self.receipts.clear()

    def snapshot(self) -> str:
        return json.dumps({"epoch": self.epoch, "record": asdict(self.record),
                           "receipts": {k: [asdict(v[0]), v[1]]
                                        for k, v in self.receipts.items()}})

    @classmethod
    def restore(cls, encoded: str):
        data = json.loads(encoded)
        store = cls(Record(**data["record"]), data["epoch"])
        store.receipts = {k: (Record(**v[0]), v[1]) for k, v in data["receipts"].items()}
        return store


@dataclass(frozen=True)
class Surface:
    epoch: int
    revision: int
    value: str
    stale_at: int
    ends_at: int
    ended: bool = False


def update_surface(old: Surface, epoch: int, revision: int,
                   value: str, stale_at: int, now: int) -> tuple[Surface, str]:
    if epoch != old.epoch:
        return old, "stale-owner"
    if old.ended or now >= old.ends_at:
        return old, "ended"
    if revision <= old.revision:
        return old, "obsolete"
    return replace(old, revision=revision, value=value, stale_at=stale_at), "updated"


def surface_status(surface: Surface, now: int) -> str:
    if surface.ended or now >= surface.ends_at:
        return "ended"
    return "stale" if now >= surface.stale_at else "fresh"


@dataclass(frozen=True)
class FeatureInputs:
    available: bool
    foreground: bool
    consent: bool
    transport_ready: bool
    read_visibility: str = "unknown"


def feature_plan(branch: str, state: FeatureInputs) -> str:
    """Product's bounded policy, not a universal Apple authorization abstraction."""
    if branch not in {"watch", "vision", "bluetooth", "health"}:
        raise ValueError("unknown branch")
    if not state.available:
        return "manual-fallback"
    if not state.consent:
        return "explain-opt-in"
    if branch == "health":
        # Empty/read-filtered results cannot tell us whether read access was denied.
        return "show-observed-data" if state.read_visibility == "samples" else "no-visible-data"
    if branch == "vision":
        return "window" if state.foreground else "pause-spatial-work"
    if branch == "watch":
        return "immediate-message" if state.transport_ready else "queue-idempotent-command"
    return "bounded-discovery" if state.foreground and state.transport_ready else "manual-fallback"


def demo() -> dict:
    ledger = EntitlementLedger()
    ledger.apply(1, Transaction("purchase-1", "demo.pro", 1, True, 100))
    before = ledger.grants("demo.pro", 50)
    ledger.apply(1, Transaction("purchase-1", "demo.pro", 2, True, 100, 60))
    merged, conflicts = merge_fields(
        {"title": "Draft", "note": "Blue"},
        {"title": "Draft A", "note": "Blue"},
        {"title": "Draft", "note": "Green"},
    )
    return {"synthetic": True, "grant_before_revoke": before,
            "grant_after_revoke": ledger.grants("demo.pro", 70),
            "merged": merged, "conflicts": conflicts,
            "surface_at_boundary": surface_status(Surface(1, 1, "queued", 20, 80), 20)}


if __name__ == "__main__":
    print(json.dumps(demo(), sort_keys=True, indent=2))
