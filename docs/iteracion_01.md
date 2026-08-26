# Iteración 1 — Base del complemento

## Objetivo

Disponer de un proyecto Godot válido con un complemento `@tool`, un nodo `PVController` registrado, un panel lateral sensible a la escena activa y una arquitectura orientada a objetos que separe responsabilidades.

## Criterios de aceptación

- Godot reconoce `addons/vp_flujo/plugin.cfg`.
- `PVController` aparece en el diálogo **Añadir nodo**.
- El panel `VPFlujo` se abre cuando la escena contiene al menos un `PVController`.
- El panel se cierra cuando la escena no contiene ninguno.
- Una clase derivada de `PVController` también es reconocida.
- La vista, el análisis de escenas y la coordinación del complemento están en clases separadas.
- Desactivar el complemento elimina el panel sin dejar conexiones activas.

## Prueba manual

1. Importa el proyecto en Godot 4.7.2 y abre `demo/main.tscn`.
2. Confirma que no haya errores del analizador GDScript.
3. Comprueba que el panel `VPFlujo` muestre “PVController detectado”.
4. Elimina temporalmente `PVController` y confirma que el panel se cierre.
5. Añade un nodo `PVController` desde el diálogo de nodos y confirma que vuelva a abrirse.
6. Crea temporalmente una clase que herede de `PVController` y comprueba que también active el panel.
7. Usa `Ctrl+S`, cierra y vuelve a abrir la escena para verificar la persistencia.

## Prompt para ChatGPT/Codex en VS Code

```text
Revisa la iteración 1 del proyecto VPFlujo para Godot 4.7.2 bajo programación orientada a objetos. Analiza project.godot, addons/vp_flujo/plugin.cfg, todos los scripts de addons/vp_flujo/editor, addons/vp_flujo/runtime/pv_controller.gd, demo/main.tscn y docs/arquitectura_poo.md. Verifica: sintaxis de GDScript, encapsulación, responsabilidad única, composición, dependencias entre clases, ciclo de vida _enter_tree/_exit_tree, registro global de PVController, reconocimiento de clases derivadas, conexiones y desconexiones de señales y eliminación segura del EditorDock. No agregues todavía el modelo de datos ni la ejecución. Si encuentras un problema, aplica el cambio mínimo y explica cómo validarlo manualmente en Godot.
```

## Próxima iteración

Crear con clases `Resource` el modelo serializable `PVProgram → PVProcess → PVRoutine → PVBlock`, con nombres, orden y listas inicialmente vacías de bloques.
