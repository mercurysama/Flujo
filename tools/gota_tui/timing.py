"""Monotonic run timing with human-readable deterministic formatting."""

from __future__ import annotations

import time
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Protocol


class TimingClock(Protocol):
    """Clock boundary used by production timing and deterministic tests."""

    def monotonic_ns(self) -> int:
        """Return a monotonic nanosecond reading."""

    def now(self) -> datetime:
        """Return the wall-clock timestamp used for observability."""


class SystemTimingClock:
    """Runtime clock backed by the platform monotonic and UTC clocks."""

    @staticmethod
    def monotonic_ns() -> int:
        return time.monotonic_ns()

    @staticmethod
    def now() -> datetime:
        return datetime.now(UTC)


def _iso_timestamp(value: datetime) -> str:
    if not isinstance(value, datetime):
        raise TypeError("TimingClock.now() must return datetime")
    if value.tzinfo is None:
        value = value.replace(tzinfo=UTC)
    return value.astimezone(UTC).isoformat()


def format_duration_ms(duration_ms: int) -> str:
    """Format milliseconds without losing the authoritative integer value."""

    if isinstance(duration_ms, bool) or not isinstance(duration_ms, int):
        raise TypeError("duration_ms must be a non-negative integer")
    if duration_ms < 0:
        raise ValueError("duration_ms must be a non-negative integer")
    if duration_ms < 1000:
        return f"{duration_ms}ms"

    total_seconds, milliseconds = divmod(duration_ms, 1000)
    if total_seconds < 60:
        return f"{total_seconds}.{milliseconds:03d}s"

    minutes, seconds = divmod(total_seconds, 60)
    if minutes < 60:
        return f"{minutes}m {seconds:02d}.{milliseconds:03d}s"

    hours, minutes = divmod(minutes, 60)
    return f"{hours}h {minutes:02d}m {seconds:02d}.{milliseconds:03d}s"


@dataclass(frozen=True, slots=True)
class RunTiming:
    """Completed wall-clock and monotonic timing for one TUI execution."""

    started_at: str
    finished_at: str
    duration_ms: int

    @property
    def duration_human(self) -> str:
        return format_duration_ms(self.duration_ms)


class RunTimer:
    """Measure one execution using monotonic time as the duration authority."""

    def __init__(self, clock: TimingClock) -> None:
        self._clock = clock
        self._started_monotonic_ns = self._read_monotonic()
        self.started_at = _iso_timestamp(clock.now())
        self._finished: RunTiming | None = None

    def _read_monotonic(self) -> int:
        value = self._clock.monotonic_ns()
        if isinstance(value, bool) or not isinstance(value, int):
            raise TypeError("TimingClock.monotonic_ns() must return an integer")
        return value

    def finish(self) -> RunTiming:
        if self._finished is not None:
            return self._finished
        finished_monotonic_ns = self._read_monotonic()
        duration_ms = max(
            0,
            (finished_monotonic_ns - self._started_monotonic_ns) // 1_000_000,
        )
        self._finished = RunTiming(
            started_at=self.started_at,
            finished_at=_iso_timestamp(self._clock.now()),
            duration_ms=duration_ms,
        )
        return self._finished


__all__ = [
    "RunTimer",
    "RunTiming",
    "SystemTimingClock",
    "TimingClock",
    "format_duration_ms",
]
