---
description: Reglas para el formato de mensajes de commit en español
globs:
alwaysApply: false
activation: Solo se activa cuando se ejecuta el comando @.cursor/commands/commit-message.md
---

Los mensajes de commit van en español y en formato markdown.

Este repo usa **conventional commits**, a diferencia de otros proyectos donde el
título es texto libre. El historial ya está escrito así (`feat(ui):`, `docs:`,
`chore(release):`) y romperlo dejaría el log a dos aguas.

## Formato

1. **Título:** una línea en conventional commit, con el resumen en español, en
   imperativo y en minúscula, sin punto final.
   - Tipos: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.
   - Ámbitos habituales: `ui`, `server`, `web`, `theme`, `tool`, `ci`.
2. **Cuerpo:** una explicación en prosa de qué cambió y por qué, y debajo una
   lista de los cambios concretos.

Nada de atribución a herramientas ni líneas `Co-Authored-By`.

Sigue el siguiente ejemplo de formato:

```
feat(server): sirve el manifest y el ícono sin token

El navegador pide el manifest y los íconos fuera del contexto de cookie de la
página cuando el celular añade FileFly a la pantalla de inicio, así que
protegerlos con el token solo producía un ícono en blanco.

## Cambios realizados:

- Se ha añadido `publicAssets` a `FileServer`, con las rutas que se sirven antes
  de la comprobación de autorización.
- Se ha añadido `buildWebManifest()` en `palette.dart`, que toma los colores de
  la paleta para `theme_color` y `background_color`.
- Se han cargado los PNG de 256 y 512 en `main.dart` y se han declarado en
  `pubspec.yaml`.
- Se ha cubierto en `palette_test.dart` que el manifest declara los íconos que
  el servidor publica.
```
