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
    _ALLOWED_COMMANDS = frozenset(
        {"cat-file", "diff", "merge-base", "rev-parse", "rev-list", "status"}
    )

    def __init__(self, repository: str | Path) -> None:
        self.repository = Path(repository).resolve()
        if not (self.repository / ".git").exists():
            raise GitReadError(f"Not a Git repository: {self.repository}")

    def _run_bytes(self, *arguments: str) -> bytes:
        if not arguments or arguments[0] not in self._ALLOWED_COMMANDS:
            raise GitReadError("The v1 Git adapter permits read-only commands only")
        result = subprocess.run(
            ("git", *arguments),
            cwd=self.repository,
            check=False,
            capture_output=True,
        )
        if result.returncode != 0:
            message = result.stderr.decode("utf-8", errors="replace").strip()
            raise GitReadError(message or "Git inspection failed")
        return result.stdout

    def _run(self, *arguments: str) -> str:
        return self._run_bytes(*arguments).decode(
            "utf-8", errors="surrogateescape"
        ).rstrip("\n")

    def head(self) -> str:
        return self._run("rev-parse", "HEAD")

    def branch(self) -> str:
        return self._run("rev-parse", "--abbrev-ref", "HEAD")

    def status_porcelain(self) -> str:
        return self._run("status", "--porcelain=v1", "--untracked-files=all")

    def object_type(self, object_sha: str) -> str:
        return self._run("cat-file", "-t", object_sha)

    def commit_exists(self, commit_sha: str) -> bool:
        try:
            return self.object_type(commit_sha) == "commit"
        except GitReadError:
            return False

    def is_ancestor(self, ancestor_sha: str, descendant_sha: str) -> bool:
        result = subprocess.run(
            ("git", "merge-base", "--is-ancestor", ancestor_sha, descendant_sha),
            cwd=self.repository,
            check=False,
            capture_output=True,
        )
        if result.returncode == 0:
            return True
        if result.returncode == 1:
            return False
        message = result.stderr.decode("utf-8", errors="replace").strip()
        raise GitReadError(message or "Git ancestry inspection failed")

    def commit_count_between(self, ancestor_sha: str, descendant_sha: str) -> int:
        raw_count = self._run(
            "rev-list", "--count", f"{ancestor_sha}..{descendant_sha}"
        )
        try:
            return int(raw_count)
        except ValueError as error:
            raise GitReadError("Git returned an invalid commit count") from error

    def changed_paths(self, ancestor_sha: str, descendant_sha: str) -> tuple[str, ...]:
        raw_paths = self._run_bytes(
            "diff",
            "--name-only",
            "-z",
            "--no-ext-diff",
            ancestor_sha,
            descendant_sha,
        )
        paths = (
            path.decode("utf-8", errors="surrogateescape")
            for path in raw_paths.split(b"\0")
            if path
        )
        return tuple(sorted(paths))

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
