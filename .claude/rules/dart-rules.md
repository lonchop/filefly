---
trigger: always_on
globs: ["lib/**/*", "test/**/*"]
alwaysApply: true
---

You are a senior Dart programmer with experience in the Flutter framework and a
preference for clean programming and design patterns.

Estas reglas aplican a FileFly: una app de escritorio Flutter para Linux y
Windows que sirve archivos por la red local. No hay Riverpod, ni GoRouter, ni
cliente HTTP, ni backend remoto. El estado vive en `_HomeScreenState` con
`setState` y esa es una decisión deliberada: una sola pantalla, un solo objeto
mutable (`FileServer`). No introduzcas un gestor de estado sin una razón escrita
en el diff.

Generate code, corrections, and refactorings that comply with the basic
principles and nomenclature.

## Idioma

- **Código en inglés, comentarios en español.** Identificadores, nombres de
  clases, funciones, variables y archivos en inglés. Comentarios y dartdoc en
  español neutro y profesional.
- La copy de la interfaz va en español, corta y llana. Ver la directiva de
  diseño en `CLAUDE.md`.
- Los mensajes de error que devuelve el servidor al teléfono ya están en
  español; mantenerlo.

## Dart General Guidelines

### Basic Principles

- Declara siempre el tipo de cada variable y función (parámetros y retorno).
  - Evita `dynamic`.
  - Crea los tipos que hagan falta. Los records tipados de este repo
    (`({String contentType, List<int> bytes})`) son un ejemplo válido.
- No dejes líneas en blanco dentro de una función.
- Un tipo principal por archivo. Los helpers que solo sirven a ese tipo se
  quedan al lado: `safeFileName` vive junto a `FileServer` porque es la defensa
  de esa clase, no una utilidad de propósito general.

### Nomenclature

- PascalCase para clases.
- camelCase para variables, funciones y métodos.
- underscores_case para archivos y directorios.
- UPPERCASE para variables de entorno.
  - Evita los números mágicos: defínelos como constantes. En este repo las
    constantes de módulo llevan prefijo `k` cuando son públicas (`kMotion`,
    `kNarrowWindow`) y `_` cuando son privadas (`_defaultPort`, `_cookieName`).
- Empieza cada función con un verbo.
- Usa verbos para los booleanos: `isRunning`, `hasError`, `canDelete`.
- Palabras completas en vez de abreviaturas, bien escritas.
  - Salvo abreviaturas estándar: API, URL, IP, HTTP.
  - Salvo abreviaturas conocidas: `i`, `j` en bucles; `err` para errores; `ctx`
    para contextos.

### Functions

- Lo que se dice de una función aplica también a un método.
- Funciones cortas y de un solo propósito. Menos de 20 instrucciones.
- Nombra la función con un verbo y algo más.
  - Si devuelve un booleano: `isX`, `hasX`, `canX`.
  - Si no devuelve nada: `saveX`, `sendX`, `startX`.
- Evita anidar bloques mediante:
  - Comprobaciones y retornos tempranos.
  - Extracción a funciones auxiliares.
- Usa funciones de orden superior (`map`, `where`, `fold`) para no anidar.
  - Flecha para funciones simples (menos de 3 instrucciones).
  - Función con nombre para el resto.
- Usa valores por defecto en los parámetros en vez de comprobar `null`.
- Reduce el número de parámetros: named parameters para todo lo que no sea
  obvio por posición, y un record o una clase cuando el retorno lleva más de un
  dato.
- Un solo nivel de abstracción por función.

### Data

- No abuses de los tipos primitivos: encapsula en tipos compuestos.
  `SharedFile` existe por eso.
- Evita validar dentro de las funciones: valida en la clase que es dueña del
  dato.
- Prefiere la inmutabilidad.
  - `final` para lo que no cambia.
  - `const` para los literales que no cambian, y constructores `const` siempre
    que se pueda.

### Classes

- Sigue los principios SOLID.
- Composición antes que herencia.
- Declara interfaces para definir contratos.
- Clases pequeñas y de un solo propósito.
  - Menos de 200 instrucciones.
  - Menos de 10 métodos públicos.
  - Menos de 10 propiedades.

### Exceptions

- Usa excepciones para los errores que no esperas.
- Si capturas una excepción, que sea para:
  - Arreglar un problema esperado.
  - Añadir contexto.
  - Si no, deja que suba a un manejador global. `FileServer._serve` es el
    ejemplo: captura por petición para que un cliente que se cae no tumbe el
    bucle del servidor.
- Falla temprano y ruidosamente cuando el fallo silencioso sería peor.
  `withPaletteTokens` lanza si falta el marcador: mejor no arrancar que servir
  una página sin estilos.

### Testing

- Sigue la convención Arrange-Act-Assert.
- Nombra las variables de test con claridad: `inputX`, `mockX`, `actualX`,
  `expectedX`.
- Escribe tests unitarios para cada función pública.
  - Usa dobles de prueba para simular dependencias.
  - Salvo dependencias de terceros que no sean caras de ejecutar.
- El servidor se prueba de verdad, no simulado: `file_server_test.dart` levanta
  un `HttpServer` en el puerto 0 contra un directorio temporal. Mantén ese
  patrón, es más barato que un mock y prueba el protocolo real.
- Cada regla que el diseño da por sentada necesita un test que la sostenga.
  `palette_test.dart` guarda el contraste WCAG AA y la inyección de la paleta;
  `layout_test.dart` guarda el punto de quiebre responsive.

## Específico de Flutter

### Principios básicos

- Una sola pantalla (`HomeScreen`) y sin navegación. Si aparece una segunda
  pantalla, se decide el enrutado antes de escribirla, no después.
- El estado del servidor y de la lista de archivos vive en `_HomeScreenState`.
  Los widgets de `lib/ui/widgets/` son de presentación: reciben datos y
  callbacks, no leen ni escriben el disco.
- Los cambios que vienen del teléfono llegan por el `Stream` `FileServer.changes`
  y se traducen a un `setState`. No hagas polling.
- Usa constructores `const` siempre que puedas.
- Árboles de widgets planos. Un árbol muy anidado cuesta tiempo de build y
  memoria, y complica seguir el estado.
- Parte los widgets grandes en widgets privados pequeños dentro del mismo
  archivo, como `_Header`, `_StatusBadge` y `_ErrorCard` en `home_screen.dart`.
  Un widget privado con nombre es más legible que un método `_buildAlgo`.
- Usa `ThemeData` para los temas: `buildTheme()` en `lib/app/theme.dart`. Nada
  de estilos sueltos en el árbol de widgets.
- Los colores salen solo de `AppColors`; los espacios, radios y duraciones solo
  de `Space`, `Radii` y `kMotion`. La directiva de diseño de `CLAUDE.md` manda
  sobre cualquier cambio de interfaz.
- Usa extensiones para el código reutilizable.
- Define las constantes en un solo sitio.

### Capa de servidor

- `lib/server/` no conoce Flutter. `file_server.dart` recibe la página como
  `String`, no toca `rootBundle`, y así se puede probar sin binding de widgets.
  Mantén esa frontera.
- Todo nombre de archivo que venga de fuera pasa por `safeFileName` antes de
  tocar el disco. Esa es la defensa completa contra el path traversal: no la
  esquives ni la dupliques.
- Toda ruta nueva del servidor entra por el bloque de autorización. Las únicas
  excepciones son los assets públicos de `publicAssets`, y hay que justificar
  cualquier añadido a esa lista.

### Testing

- Widget tests estándar de Flutter para la ventana.
- El ciclo completo contra el servidor se prueba con `HttpClient` real, no con
  dobles.
