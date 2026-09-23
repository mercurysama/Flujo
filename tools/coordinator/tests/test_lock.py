from __future__ import annotations

import multiprocessing
import time
from datetime import UTC, datetime, timedelta

from flow_coordinator.lock import GlobalLockManager, LockHeldError
from flow_coordinator.store import (
    FencingTokenError,
    LeaseExpiredError,
    SQLiteCoordinatorStore,
)

from support import CoordinatorTestCase


def _contending_lock_worker(database: str, owner: str, gate, output) -> None:
    store = SQLiteCoordinatorStore(database)
    manager = GlobalLockManager(store)
    gate.wait(5)
    try:
        lease = manager.acquire(owner, "run", lease_seconds=10)
        output.put(("acquired", owner, lease.fencing_token))
        time.sleep(0.4)
        manager.release(lease)
    except LockHeldError:
        output.put(("held", owner, None))


class GlobalLockTest(CoordinatorTestCase):
    def test_two_processes_cannot_hold_global_lock_simultaneously(self) -> None:
        context = multiprocessing.get_context("spawn")
        gate = context.Event()
        output = context.Queue()
        workers = [
            context.Process(
                target=_contending_lock_worker,
                args=(str(self.database), owner, gate, output),
            )
            for owner in ("one", "two")
        ]
        for worker in workers:
            worker.start()
        gate.set()
        results = [output.get(timeout=10) for _ in workers]
        for worker in workers:
            worker.join(timeout=10)
            self.assertEqual(worker.exitcode, 0)
        self.assertEqual(sum(result[0] == "acquired" for result in results), 1)
        self.assertEqual(sum(result[0] == "held" for result in results), 1)

    def test_each_acquisition_increments_fencing_token(self) -> None:
        manager = GlobalLockManager(self.store)
        first = manager.acquire("owner-a", "run-a")
        manager.release(first)
        second = manager.acquire("owner-b", "run-b")
        self.assertEqual(second.fencing_token, first.fencing_token + 1)

    def test_old_owner_cannot_write_with_obsolete_token(self) -> None:
        _, run = self.create_task("fencing")
        manager = GlobalLockManager(self.store)
        first = manager.acquire("owner-a", run.run_id)
        manager.release(first)
        second = manager.acquire("owner-b", run.run_id)
        with self.assertRaises(FencingTokenError):
            self.store.append_checkpoint(run.run_id, {"step": "old"}, first)
        current = self.store.append_checkpoint(run.run_id, {"step": "new"}, second)
        self.assertEqual(current.payload["step"], "new")

    def test_expired_lease_becomes_stale_and_requires_authorized_recovery(self) -> None:
        manager = GlobalLockManager(self.store)
        start = datetime(2026, 1, 1, tzinfo=UTC)
        first = manager.acquire("owner-a", "run-a", lease_seconds=1, now=start)
        with self.assertRaises(LeaseExpiredError):
            manager.acquire("owner-b", "run-b", now=start + timedelta(seconds=2))
        state = manager.inspect()
        self.assertEqual(state["owner_id"], "owner-a")
        self.assertEqual(state["stale"], 1)
        with self.assertRaises(PermissionError):
            manager.recover_stale(authorized=False)
        manager.recover_stale(authorized=True)
        second = manager.acquire("owner-b", "run-b", now=start + timedelta(seconds=3))
        self.assertEqual(second.fencing_token, first.fencing_token + 1)

    def test_expired_lease_cannot_be_released_silently(self) -> None:
        manager = GlobalLockManager(self.store)
        start = datetime(2026, 1, 1, tzinfo=UTC)
        lease = manager.acquire("owner", "run", lease_seconds=1, now=start)
        with self.assertRaises(LeaseExpiredError):
            manager.release(lease, now=start + timedelta(seconds=2))
        self.assertEqual(manager.inspect()["stale"], 1)


if __name__ == "__main__":
    import unittest

    unittest.main()
