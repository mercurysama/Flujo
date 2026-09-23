"""Transactional global lease and monotonic fencing token."""

from __future__ import annotations

from contextlib import closing
from datetime import datetime, timedelta

from .domain import Lease, isoformat, parse_datetime, utc_now
from .store import FencingTokenError, LeaseExpiredError, SQLiteCoordinatorStore


class LockHeldError(RuntimeError):
    pass


class StaleLockError(RuntimeError):
    pass


class GlobalLockManager:
    def __init__(self, store: SQLiteCoordinatorStore) -> None:
        self.store = store

    def acquire(
        self,
        owner_id: str,
        run_id: str,
        *,
        lease_seconds: int = 60,
        now: datetime | None = None,
    ) -> Lease:
        if not owner_id or not run_id or lease_seconds <= 0:
            raise ValueError("owner_id, run_id, and a positive lease are required")
        current_time = now or utc_now()
        expires_at = current_time + timedelta(seconds=lease_seconds)
        expired: str | None = None
        acquired: Lease | None = None
        with self.store.transaction(immediate=True) as connection:
            row = connection.execute(
                "SELECT * FROM global_lock WHERE lock_name = 'global'"
            ).fetchone()
            if row["owner_id"] is not None:
                if bool(row["stale"]):
                    raise StaleLockError(
                        f"Global lock is stale and requires authorized recovery: {row['owner_id']}"
                    )
                if parse_datetime(row["lease_expires_at"]) <= current_time:
                    connection.execute(
                        "UPDATE global_lock SET stale = 1 WHERE lock_name = 'global'"
                    )
                    expired = row["owner_id"]
                else:
                    raise LockHeldError(
                        f"Global lock is held by {row['owner_id']} for run {row['run_id']}"
                    )
            else:
                token = int(row["fencing_token"]) + 1
                connection.execute(
                    """
                    UPDATE global_lock
                    SET owner_id = ?, run_id = ?, fencing_token = ?, acquired_at = ?,
                        heartbeat_at = ?, lease_expires_at = ?, stale = 0
                    WHERE lock_name = 'global'
                    """,
                    (
                        owner_id,
                        run_id,
                        token,
                        isoformat(current_time),
                        isoformat(current_time),
                        isoformat(expires_at),
                    ),
                )
                acquired = Lease(owner_id, run_id, token, current_time, expires_at)
        if expired is not None:
            raise LeaseExpiredError(
                f"Expired lease owned by {expired} remains stale until authorized recovery"
            )
        assert acquired is not None
        return acquired

    def heartbeat(
        self,
        lease: Lease,
        *,
        lease_seconds: int = 60,
        now: datetime | None = None,
    ) -> Lease:
        current_time = now or utc_now()
        expires_at = current_time + timedelta(seconds=lease_seconds)
        with self.store.fenced_transaction(lease, now=current_time) as connection:
            connection.execute(
                """
                UPDATE global_lock SET heartbeat_at = ?, lease_expires_at = ?
                WHERE lock_name = 'global'
                """,
                (isoformat(current_time), isoformat(expires_at)),
            )
        return Lease(
            lease.owner_id,
            lease.run_id,
            lease.fencing_token,
            lease.acquired_at,
            expires_at,
        )

    def release(self, lease: Lease, *, now: datetime | None = None) -> None:
        current_time = now or utc_now()
        with self.store.fenced_transaction(lease, now=current_time) as connection:
            connection.execute(
                """
                UPDATE global_lock
                SET owner_id = NULL, run_id = NULL, acquired_at = NULL,
                    heartbeat_at = NULL, lease_expires_at = NULL, stale = 0
                WHERE lock_name = 'global'
                """
            )

    def recover_stale(self, *, authorized: bool) -> None:
        if not authorized:
            raise PermissionError("Stale lock recovery requires explicit authorization")
        with self.store.transaction(immediate=True) as connection:
            row = connection.execute(
                "SELECT stale FROM global_lock WHERE lock_name = 'global'"
            ).fetchone()
            if not bool(row["stale"]):
                raise StaleLockError("Global lock is not marked stale")
            connection.execute(
                """
                UPDATE global_lock
                SET owner_id = NULL, run_id = NULL, acquired_at = NULL,
                    heartbeat_at = NULL, lease_expires_at = NULL, stale = 0
                WHERE lock_name = 'global'
                """
            )

    def inspect(self) -> dict[str, object]:
        with closing(self.store._connect()) as connection:
            row = connection.execute(
                "SELECT * FROM global_lock WHERE lock_name = 'global'"
            ).fetchone()
        return dict(row)

    def assert_current(self, lease: Lease, *, now: datetime | None = None) -> None:
        with self.store.fenced_transaction(lease, now=now):
            pass


__all__ = [
    "FencingTokenError",
    "GlobalLockManager",
    "LeaseExpiredError",
    "LockHeldError",
    "StaleLockError",
]
