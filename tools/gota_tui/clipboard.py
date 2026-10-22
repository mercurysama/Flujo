"""Safe, injectable system clipboard boundaries."""

from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass
from typing import Callable, Sequence


class ClipboardError(RuntimeError):
    """Base class for clipboard diagnostics."""


class ClipboardUnavailable(ClipboardError):
    """No supported clipboard backend is available."""


class ClipboardCommandError(ClipboardError):
    """A supported clipboard backend failed to serve the request."""


Which = Callable[[str], str | None]
Run = Callable[..., subprocess.CompletedProcess[bytes]]


@dataclass(frozen=True, slots=True)
class ClipboardBackend:
    name: str
    executable: str
    read_argv: tuple[str, ...]
    write_argv: tuple[str, ...]


BACKENDS: tuple[ClipboardBackend, ...] = (
    ClipboardBackend("wayland", "wl-paste", ("wl-paste", "--no-newline"), ("wl-copy",)),
    ClipboardBackend(
        "xclip",
        "xclip",
        ("xclip", "-selection", "clipboard", "-o"),
        ("xclip", "-selection", "clipboard"),
    ),
    ClipboardBackend(
        "xsel",
        "xsel",
        ("xsel", "--clipboard", "--output"),
        ("xsel", "--clipboard", "--input"),
    ),
)


def _decode_clipboard(value: bytes, backend: str) -> str:
    try:
        return value.decode("utf-8")
    except UnicodeDecodeError as error:
        raise ClipboardCommandError(
            f"Clipboard backend {backend} returned invalid UTF-8: {error}"
        ) from error


class ClipboardReader:
    """Read clipboard text without ever executing its contents."""

    def __init__(
        self,
        *,
        which: Which = shutil.which,
        run: Run = subprocess.run,
        backends: Sequence[ClipboardBackend] = BACKENDS,
        timeout: float = 2.0,
    ) -> None:
        self._which = which
        self._run = run
        self._backends = tuple(backends)
        self.timeout = timeout
        self.last_backend: str | None = None

    def _available(self) -> tuple[ClipboardBackend, ...]:
        return tuple(
            backend
            for backend in self._backends
            if self._which(backend.executable) is not None
        )

    def available_backends(self) -> tuple[ClipboardBackend, ...]:
        """Return reader backends available without invoking any command."""

        return self._available()

    def read(self) -> str:
        available = self.available_backends()
        if not available:
            names = ", ".join(backend.executable for backend in self._backends)
            raise ClipboardUnavailable(
                f"No clipboard reader is available; install one of: {names}"
            )
        failures: list[str] = []
        for backend in available:
            try:
                result = self._run(
                    list(backend.read_argv),
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    check=True,
                    timeout=self.timeout,
                    shell=False,
                )
                self.last_backend = backend.name
                return _decode_clipboard(result.stdout, backend.name)
            except (OSError, subprocess.SubprocessError, ClipboardCommandError) as error:
                failures.append(f"{backend.name}: {error}")
        raise ClipboardCommandError("Clipboard read failed: " + "; ".join(failures))


class ClipboardWriter:
    """Copy report text using the same explicit backend ordering."""

    def __init__(
        self,
        *,
        which: Which = shutil.which,
        run: Run = subprocess.run,
        backends: Sequence[ClipboardBackend] = BACKENDS,
        timeout: float = 2.0,
    ) -> None:
        self._which = which
        self._run = run
        self._backends = tuple(backends)
        self.timeout = timeout
        self.last_backend: str | None = None

    def _available(self) -> tuple[ClipboardBackend, ...]:
        return tuple(
            backend
            for backend in self._backends
            if self._which(
                "wl-copy" if backend.name == "wayland" else backend.executable
            )
            is not None
        )

    def available_backends(self) -> tuple[ClipboardBackend, ...]:
        """Return writer backends available without invoking any command."""

        return self._available()

    def copy(self, text: str) -> str:
        if type(text) is not str:
            raise TypeError("Clipboard text must be a string")
        available = self.available_backends()
        if not available:
            names = ", ".join(backend.executable for backend in self._backends)
            raise ClipboardUnavailable(
                f"No clipboard writer is available; install one of: {names}"
            )
        failures: list[str] = []
        for backend in available:
            try:
                result = self._run(
                    list(backend.write_argv),
                    input=text.encode("utf-8"),
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    check=True,
                    timeout=self.timeout,
                    shell=False,
                )
                del result
                self.last_backend = backend.name
                return backend.name
            except (OSError, subprocess.SubprocessError) as error:
                failures.append(f"{backend.name}: {error}")
        raise ClipboardCommandError("Clipboard copy failed: " + "; ".join(failures))
