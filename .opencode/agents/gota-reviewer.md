---
description: Audita una gota terminada de Flujo sin modificar el proyecto
mode: primary
steps: 80
permissions:
  - action: "*"
    resource: "*"
    effect: deny

  - action: read
    resource: "*"
    effect: allow
  - action: glob
    resource: "*"
    effect: allow
  - action: grep
    resource: "*"
    effect: allow

  - action: shell
    resource: "pwd"
    effect: allow
  - action: shell
    resource: "git status --short --branch"
    effect: allow
  - action: shell
    resource: "git branch --show-current"
    effect: allow
  - action: shell
    resource: "git rev-parse HEAD"
    effect: allow
  - action: shell
    resource: "git rev-parse HEAD^"
    effect: allow
  - action: shell
    resource: "git diff HEAD^..HEAD"
    effect: allow
  - action: shell
    resource: "git diff --name-only HEAD^..HEAD"
    effect: allow
  - action: shell
    resource: "git diff --check HEAD^..HEAD"
    effect: allow
  - action: shell
    resource: "git show --stat --oneline HEAD"
    effect: allow
  - action: shell
    resource: "git log -1 --oneline"
    effect: allow
---
