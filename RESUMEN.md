# ZK-Custom · Resumen del proyecto

> Personalizador visual de Windows 11, portátil y reversible.
> Repositorio privado: https://github.com/ZiCkZk/zk-custom · Estado: noviembre de 2026

---

## 1. Qué es

ZK-Custom es un asistente gráfico que cambia **solo el aspecto** de Windows 11: colores, barra de tareas, menú Inicio, ventanas, iconos, cursores, fondos, fuentes y más.

- **Ves antes de aplicar.** Cada opción tiene vista previa en un escritorio simulado.
- **Todo se puede deshacer.** Antes de cada cambio se guarda una copia.
- **Es portátil.** No necesita instalación: se abre con `ZK-Custom.exe`.
- **Solo Windows 11.** En Windows 10 avisa y no se abre.

---

## 2. Cómo se usa

| Quiero... | Cómo |
|---|---|
| Abrir el personalizador | Doble clic en `ZK-Custom.exe` (pide permisos de administrador) |
| Abrirlo sin el .exe | `Wizard.cmd` |
| Aplicar mi `config.json` en otro PC | `Install.cmd` |
| Ver qué haría sin tocar nada | `Install.cmd -DryRun` |
| Deshacer la última aplicación | Botón *Deshacer último cambio*, o `Restore.ps1` |
| Actualizar temas y fondos | Botón *Actualizar catálogo* |

**Flujo dentro de la app:**

1. Eliges un **tema listo**, o vas sección por sección.
2. **Pasas el ratón** por una tarjeta y la vista previa cambia al momento.
3. Ajustas los detalles en el panel **Ajustes**, que tiene modo Básico y Avanzado.
4. Las secciones con cambios pendientes llevan un **punto naranja**.
5. **Aplicar a mi PC** aplica todo lo pendiente; el progreso se ve en **Registro**.
6. **Guardar en config.json** deja tus elecciones listas para `Install.cmd`.

---

## 3. Qué se puede personalizar (27 secciones)

| Grupo | Secciones y contenido |
|---|---|
| **Inicio** | **Mis perfiles:** guardar, cargar, exportar e importar tu estilo completo. **Temas listos:** 17 combinaciones completas. |
| **Colores** | **Paleta:** 25 paletas, entre ellas oscuras, neón, cálidas y 4 claras. **Día y noche:** cambia de paleta automáticamente según la hora. |
| **Escritorio** | **Fondo:** 600 fondos en 31 categorías, búsqueda en **Wallhaven** a juego con tu paleta, o una imagen tuya; también para la pantalla de bloqueo. **Fondo animado:** con Lively en segundo plano; también como salvapantallas. **Barra de tareas** y su tamaño. **Botón Inicio:** el logo de Windows en 9 colores, o **Mis orbs** con búsqueda en DeviantArt. **Reloj**, **menú Inicio** y **notificaciones**. |
| **Ventanas** | Explorador, app Configuración, efectos (cristal, acrílico, Mica), esquinas, bordes y menús contextuales. |
| **Iconos y ratón** | 175 packs de iconos, carpetas de colores, 55 cursores (36 packs reales y 19 dibujados), estela del ratón y rectángulo de selección. |
| **Pantalla de bloqueo** | Reloj de bloqueo con 10 estilos. |
| **Terminal** | 22 Nerd Fonts, tamaño y opacidad. |
| **Detalles** | Ajustes visuales nativos, como el menú contextual completo, las extensiones de archivo o los iconos del escritorio. |

---

## 4. Funciones destacadas

- **Vista previa para todo.**
  - Los iconos y cursores muestran sus imágenes reales, sacadas del propio pack.
  - El resto se dibuja con tu paleta.
- **Cambios por sección.**
  - Elegir algo en una sección solo marca esa sección.
  - Al aplicar, solo se reenvían a Windhawk los mods que cambiaron.
- **Interfaz con tus colores.**
  - La ventana de ZK-Custom usa tu paleta.
  - Si no has elegido ninguna, usa el color de acento y el modo claro u oscuro de Windows.
- **DeviantArt dentro de la app.**
  - Buscas un personaje o un juego y los resultados salen como tarjetas.
  - Al elegir uno, se convierte en orb con sus estados: normal, al pasar el ratón y pulsado.
- **Convertidor de orbs.**
  - Si la imagen tiene fondo transparente, se respeta su forma.
  - Si no, se mete en una esfera con aro y reflejo.
- **Wallhaven.**
  - Solo trae fondos aptos para todos, de 1920×1080 o más.
  - El botón *A juego con mi paleta* filtra por tu color principal.
  - Tiene paginación con *Más resultados*.
- **Lively Wallpaper, oculto.**
  - Los fondos animados usan tu paleta, o tu propio vídeo o GIF.
  - Lively arranca con Windows y no muestra ventana.
- **Windhawk automático.**
  - Se instala y configura por línea de comandos, sin ventanas y sin icono en la bandeja.
- **Icono propio.**
  - Es un marco naranja con «ZK» y un trazo de pincel con los colores de la paleta.
  - Aparece en el `.exe` y en la barra de tareas.

---

## 5. Seguridad y límites

- **Copia antes de tocar.**
  - El registro se exporta a `backups\<fecha>\*.reg`.
  - Windhawk se respalda con su propia exportación.
- **Descargas verificadas.**
  - Con SHA-256 si el origen lo publica; si no, por tamaño.
- **Nunca se ejecutan `.exe` de packs descargados.**
  - Los cursores se instalan leyendo su `.inf`, sin ejecutarlo.
- **Las fuentes se instalan solo para tu usuario.**
- **Contenido de terceros.**
  - No se dibujan ni se incluyen logos de marcas ni personajes.
  - Lo que importas de DeviantArt se queda solo en tu equipo, en `assets/orbs/library/`, y no se sube a GitHub.
- **VSThemes, descartado.**
  - No tiene API, bloquea a los bots y muchos packs traen instaladores `.exe`.

---

## 6. Estructura de archivos

```
Personalizacion/
├─ ZK-Custom.exe            Lanzador (abre Wizard.ps1 sin consola)
├─ Wizard.ps1 / .cmd        Asistente gráfico (WPF) con vista previa
├─ Install.ps1 / .cmd       Aplica config.json con los módulos
├─ Restore.ps1              Deshace la última aplicación
├─ config.json              Tus elecciones
├─ RESUMEN.md               Este documento
├─ README.md                Guía de uso
├─ catalog/
│  ├─ Build-*.ps1           Generan catálogo y vistas previas (iconos, cursores, fuentes)
│  ├─ static/               Temas, paletas, cursores, fuentes, efectos, botón Inicio...
│  ├─ generated/            Mods de Windhawk, iconos, cursores dibujados, fondos
│  ├─ animated/             Plantilla HTML de los fondos animados
│  └─ previews/             Vistas previas locales (iconos, cursores, fuentes)
├─ modules/
│  ├─ Core.psm1             Registro, descargas, copias, lectura de .inf
│  ├─ Windhawk.psm1         Instalar, configurar y ocultar Windhawk
│  ├─ 10-Theme … 75-DayNight  Un módulo por área (tema, ajustes, barra, cursores, fuentes,
│  │                        carpetas, fondo, fondo animado, terminal, día y noche)
│  ├─ IconTools.ps1         Extrae iconos y cursores reales
│  └─ OrbArt / OrbPremium   Carpetas de colores y convertidor de orbs
├─ tools/
│  ├─ Switch-DayNight.ps1   Tarea programada de día y noche
│  └─ launcher/             Código del .exe, icono (IconArt.ps1) y Build-Launcher.ps1
├─ docs/DECISIONES.md       Decisiones de diseño y por qué
├─ profiles/                Perfiles guardados (se crea al guardar el primero)
├─ assets/                  Tus fondos y orbs (los personales no se suben)
├─ cache/                   Descargas y miniaturas (no se sube)
└─ backups/                 Copias de cada aplicación (no se sube)
```

---

## 7. Tecnología

- **PowerShell 5.1 y WPF.** Viene con Windows, así que no hay nada que instalar.
- **Codificación de scripts.** Los que llevan tildes se guardan en UTF-8 con BOM.
- **Windhawk 2.0 (`windhawk-cli`).** La mayoría de los estilos son mods suyos.
- **Lively Wallpaper (`Livelycu.exe`).** Fondos animados y salvapantallas.
- **APIs públicas:**
  - GitHub releases, con caché de 24 h.
  - Wallhaven.
  - oEmbed de DeviantArt.
  - `wsrv.nl` para las miniaturas.
- **Lanzador.** `ZK-Custom.exe` se compila con el `csc.exe` de .NET Framework 4 que trae Windows.

---

## 8. Historial

| Commit | Cambio |
|---|---|
| `07f2fb0` | Primera versión: personalizador visual de Windows 11 |
| `48b0a64` | Vistas previas para todo, cambios por sección y *Probar 20 s* (después retirado) |
| `f4aa656` | Orbs rediseñados, DeviantArt en la app, Lively en segundo plano y perfiles |
| `e4d6d37` | Botón Inicio: solo colores del logo y Mis orbs |
| `cc9825f` | Wallhaven a juego con tu paleta y 15 packs de cursores de GitHub |
| `b7cc53e` | Icono nuevo en el .exe y en la ventana |

---

## 9. Para regenerar contenido

| Qué | Comando (desde la carpeta del proyecto) |
|---|---|
| Catálogo completo | `powershell -ExecutionPolicy Bypass -File catalog\Build-Catalog.ps1` |
| Vistas previas de iconos | `powershell -STA -ExecutionPolicy Bypass -File catalog\Build-IconPreviews.ps1` |
| Vistas previas de cursores | `powershell -STA -ExecutionPolicy Bypass -File catalog\Build-CursorPreviews.ps1` |
| Muestras de fuentes | `powershell -STA -ExecutionPolicy Bypass -File catalog\Build-FontPreviews.ps1` |
| Icono y `ZK-Custom.exe` | `powershell -STA -ExecutionPolicy Bypass -File tools\launcher\Build-Launcher.ps1` |
| Prueba automática | `powershell -STA -ExecutionPolicy Bypass -File Wizard.ps1 -SelfTest` |
