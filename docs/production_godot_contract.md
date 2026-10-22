# Production Godot validation

## GODOT-PIN-001 — authoritative executor

PRODUCTION: Godot `4.7.2.stable.official.ed1daf0bf` pinned is the minimum
reproducible validation authority. Resolve `FLUJO_GODOT_BIN` when present;
otherwise use `${XDG_DATA_HOME:-$HOME/.local/share}/flujo/toolchains/godot/4.7.2-stable/godot`.
An empty override, missing/non-executable file, failed version probe, or any
non-exact version fails closed. An invalid override never falls through to
the canonical path. Never search PATH or invoke Flatpak as a production fallback.
Paths are user configuration, not repository-specific absolute paths.

SYSTEM: distribution Godot (including Fedora builds) is an independent opt-in
compatibility/diagnostic lane. Existing native/Flatpak commands may be run
explicitly for that lane, but cannot substitute for production evidence.

FUTURE: new releases such as 4.8 are tested in parallel before explicitly
changing the supported minimum and this pinned authority.

## GODOT-PIN-002 — shared verification entrypoint

`tools/godot/resolve_godot.py` owns selection and the bounded exact-version
probe. Both versioned baseline/prove skills and AGENTS use it. From any
project root, using the helper's location in the governance checkout:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B tools/godot/resolve_godot.py
PYTHONDONTWRITEBYTECODE=1 python3 -B tools/godot/resolve_godot.py -- --headless --editor --path . --quit-after 5
PYTHONDONTWRITEBYTECODE=1 python3 -B tools/godot/resolve_godot.py -- --headless --path . --script tests/governance/behavior_catalog_validator_test.gd
PYTHONDONTWRITEBYTECODE=1 python3 -B tools/godot/resolve_godot.py -- --headless --path . tests/model/flow_model_smoke_test.tscn
```

Without arguments it prints the selected absolute executable path. After `--`,
arguments are passed literally without a shell; the child exit status is
propagated. Each invocation revalidates the selected executable. The helper
does not select a project, write state, download, install, or update Godot.
The Coordinator core remains Godot-independent.

## GODOT-PIN-003 — acceptance and trace

Use fake executables in `tests/tooling/test_godot_resolver.py` for override,
canonical selection, XDG/HOME, absent/non-executable, version rejection including
Fedora, and no-PATH-fallback cases. Run with:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest discover -s tests/tooling -v
```

Trace: GODOT-PIN-001/002/003 → resolver + baseline/prove + AGENTS →
FLUJO-BHV-GODOT-PRODUCTION-001 → fake tests and real production validator/editor/
model runs → `chore: pin Godot 4.7.2 for production validation`.

Centralization avoids divergent skill rules; accepting any same-commit build,
PATH fallback, per-machine configuration and changing the Coordinator were
rejected. Protect model/schema/runtime/UI, real Flujo checkout, historical
pilots and SQLite evidence. No visual review is required. Exact version checking
does not authenticate arbitrary override bytes: installation provenance and
official ZIP checksum verification remain an operator responsibility. Binary
replacement between probe and launch is not prevented. No historical Godot debt
is repaired. Test results and available counts are recorded in delivery evidence;
lead time, review time and credits are not measured.
