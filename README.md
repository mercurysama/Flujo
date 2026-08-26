# VPFlujo

VPFlujo es un complemento de programación visual por bloques para Godot, inspirado en el flujo de trabajo de GameFlow y en la lectura secuencial de Scratch.

Esta primera iteración contiene:

- un complemento de editor en `addons/vp_flujo`;
- el nodo global `PVController`;
- un panel lateral que solo se abre cuando la escena tiene un `PVController`;
- clases separadas para coordinación, presentación, análisis de escena y ejecución futura;
- una escena de demostración lista para ejecutar.

## Requisitos

- Godot 4.7.2 estable;
- VS Code con la extensión Godot Tools;
- el complemento de ChatGPT/Codex que se usará para desarrollar cada iteración.

## Puesta en marcha

1. Importa `project.godot` desde el administrador de proyectos de Godot.
2. Abre `demo/main.tscn`.
3. Comprueba en **Proyecto > Ajustes del proyecto > Plugins** que `VPFlujo` esté habilitado.
4. El panel `VPFlujo` aparecerá en el área derecha porque la escena ya incluye un `PVController`.
5. Guarda normalmente con `Ctrl+S`.

Si quitas el nodo `PVController`, el panel se oculta; al volver a agregarlo, reaparece.

Consulta [docs/arquitectura_poo.md](docs/arquitectura_poo.md) para conocer el diseño de clases y [docs/iteracion_01.md](docs/iteracion_01.md) para las pruebas y el prompt de revisión en VS Code.

