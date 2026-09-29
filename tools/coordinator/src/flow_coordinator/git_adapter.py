"""Read-only Git inspection adapter."""

from __future__ import annotations

import hashlib
import subprocess
from dataclasses import dataclass
from pathlib import Path


class GitReadError(RuntimeError):
    pass


@dataclass(frozen=True, slots=True)
class GitSnapshot:
    repository: str
    head: str
    branch: str
    status: str


class ReadOnlyGitAdapter:
    _ALLOWED_COMMANDS = frozenset({"rev-parse", "status"})

    def __init__(self, repository: str | Path) -> None:
        self.repository = Path(repository).resolve()
        if not (self.repository / ".git").exists():
            raise GitReadError(f"Not a Git repository: {self.repository}")

    def _run(self, *arguments: str) -> str:
        if not arguments or arguments[0] not in self._ALLOWED_COMMANDS:
            raise GitReadError("The v1 Git adapter permits read-only commands only")
        result = subprocess.run(
            ("git", *arguments),
            cwd=self.repository,
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise GitReadError(result.stderr.strip() or "Git inspection failed")
        return result.stdout.rstrip("\n")

    def head(self) -> str:
        return self._run("rev-parse", "HEAD")

    def branch(self) -> str:
        return self._run("rev-parse", "--abbrev-ref", "HEAD")

    def status_porcelain(self) -> str:
        return self._run("status", "--porcelain=v1", "--untracked-files=all")

    def snapshot(self) -> GitSnapshot:
        return GitSnapshot(
            repository=str(self.repository),
            head=self.head(),
            branch=self.branch(),
            status=self.status_porcelain(),
        )

    def file_hash(self, relative_path: str) -> str:
        path = (self.repository / relative_path).resolve()
        try:
            path.relative_to(self.repository)
        except ValueError as error:
            raise GitReadError("File must remain inside the repository") from error
        return hashlib.sha256(path.read_bytes()).hexdigest()
