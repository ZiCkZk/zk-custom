# ZK-Custom · Personalizador visual de Windows 11

Asistente gráfico e instalador portátil para personalizar el aspecto de Windows 11 de forma reversible.
Solo hace cambios visuales y solo funciona en Windows 11: en Windows 10 avisa y no abre.

## Uso

| Acción | Cómo |
|---|---|
| **Abrir el personalizador** | Doble clic en **`ZK-Custom.exe`** (pide permisos de administrador) |
| Alternativa sin .exe | Doble clic en `Wizard.cmd` |
| Aplicar `config.json` de una vez (otro equipo) | Doble clic en `Install.cmd` |
| Ver qué haría sin tocar nada | `Install.cmd -DryRun` |
| Deshacer la última aplicación | Botón *Deshacer último cambio*, o `powershell -ExecutionPolicy Bypass -File Restore.ps1` |
| Actualizar temas y fondos | Botón *Actualizar catálogo* |

La primera vez que abras `ZK-Custom.exe`, Windows SmartScreen puede avisar porque el programa no está firmado. Pulsa *Más información* y luego *Ejecutar de todas formas*.

### Cómo funciona

1. **Temas listos** (Inicio): 17 combinaciones completas (con orb, tamaño de barra, bordes, menús y reloj de bloqueo), cada una con una vista previa de cómo queda el escritorio.
2. Cada sección muestra sus opciones en tarjetas. **Pasar el ratón** por una tarjeta la muestra al momento en la **vista previa** de arriba, que es un escritorio simulado con tu fondo, tu paleta, la barra, las ventanas, el menú y el puntero.
3. El panel derecho **Ajustes** tiene un modo **Básico** y otro **Avanzado**:
   - **Básico:** colores de tu paleta, acento, transparencia y redondeo.
   - **Avanzado:** fondo, borde y texto por separado.
   - La vista previa dibuja la barra, el menú Inicio, las notificaciones, el Explorador, la app Configuración y la terminal con esos ajustes. Al pasar el ratón por una tarjeta se ve la captura del tema; sin ratón, el tema elegido aparece en miniatura en la esquina.
   - **Botón Inicio:** 22 orbs dibujados para ZK-Custom (esfera de cristal, anillo neón, círculo, cuadrado redondeado, contorno y planeta), 30 orbs gamer y de cómic (corazón y espada pixel, moneda, estrella, mando, joystick, poción, escudo, dado de rol, shuriken, rayo, «POW!», «BOOM!» y «WOW!"), 4 orbs con los colores de tu paleta, tu biblioteca **Mis orbs** (importas varias imágenes de golpe; el buscador abre imágenes con fondo transparente y DeviantArt para el personaje o juego que escribas) o un orb con estados en modo avanzado. Puedes subir hasta 3 imágenes: normal, al pasar el ratón y pulsado. Admite PNG, JPG y GIF animado. También puedes ajustar el tamaño, cuánto crece y gira al pasar el ratón y la animación del GIF.
4. Las secciones con cambios sin aplicar llevan un punto naranja. **Aplicar a mi PC** aplica todo lo pendiente de una vez y el progreso se ve en la pestaña **Registro**.
5. **Guardar en config.json** deja tus elecciones listas para `Install.cmd`.

### Secciones

| Grupo | Secciones |
|---|---|
| Inicio | Temas listos |
| Colores | Paleta (25: oscuras, neón, cálidas, verdes, rojas, doradas, grises y 4 claras), día y noche automático (cambia la paleta según la hora) |
| Escritorio | Fondo (600 en 31 categorías o una imagen tuya, también para la pantalla de bloqueo), fondo animado (6 propios con tu paleta o tu vídeo/GIF, con Lively Wallpaper), barra de tareas, tamaño de la barra, botón Inicio, reloj, menú Inicio, notificaciones |
| Ventanas | Explorador, app Configuración, efectos (cristal, acrílico, Mica), esquinas, bordes, menús contextuales |
| Iconos y ratón | Iconos (175 packs), carpetas de colores, cursores, estela del ratón (largo, grosor y color), rectángulo de selección |
| Pantalla de bloqueo | Reloj de bloqueo (10 estilos) |
| Terminal | Fuente (22 Nerd Fonts, cada muestra dibujada con su letra real), tamaño y opacidad |
| Detalles | Ajustes visuales nativos (menú contextual completo, extensiones, iconos del escritorio...) |

## Windhawk, automático y oculto

Casi todos los estilos son mods de [Windhawk](https://windhawk.net):

- Se instala solo desde GitHub, verificado con su SHA-256.
- Se configura por línea de comandos, sin abrir ninguna ventana.
- Queda oculto: sin icono en la bandeja.
- Cada mod recibe su configuración completa, así que no quedan restos de personalizaciones anteriores.
- Al cambiar el pack de iconos, el Explorador se cierra un segundo, se vacía la caché de iconos y se vuelve a abrir, **sin preguntarte**.

## Estructura

```
Personalizacion/                   (carpeta del proyecto ZK-Custom)
├─ ZK-Custom.exe                  lanzador (abre Wizard.ps1 sin consola)
├─ Wizard.ps1 / Wizard.cmd        asistente con vista previa en vivo
├─ Install.ps1 / Install.cmd      aplica config.json
├─ Restore.ps1                    deshace una aplicación
├─ config.json                    tus elecciones
├─ catalog/
│  ├─ Build-Catalog.ps1           lee mods de Windhawk, capturas y galerías de fondos
│  ├─ Build-FontPreviews.ps1      dibuja la muestra de cada fuente con su letra real
│  ├─ generated/                  barra, Inicio, Explorador, notificaciones, Configuración, iconos, cursores, fondos
│  ├─ static/                     temas listos, paletas, cursores, fuentes, efectos, esquinas, bordes, menús,
│  │                              selección, estela, reloj, reloj de bloqueo, tamaño de barra, botón Inicio, ajustes
│  └─ previews/fonts/             muestras de las fuentes
├─ modules/                       Core, Windhawk y los módulos 10-Theme ... 70-Terminal
├─ tools/launcher/                código del .exe, icono y Build-Launcher.ps1 para recompilarlo
├─ assets/                        tu fondo propio
├─ docs/DECISIONES.md             decisiones de diseño
├─ cache/                         descargas, miniaturas y respuestas de GitHub (no se versiona)
└─ backups/                       copia de cada aplicación (no se versiona)
```

## Rapidez de las vistas previas

- Las tarjetas usan miniaturas ligeras, de unos 10-30 KB, que se guardan en `cache\thumbs`. La segunda vez cargan al instante y sin internet.
- Al abrir, ZK-Custom descarga en segundo plano las miniaturas de todos los catálogos, y al entrar en una sección precarga sus imágenes grandes.
- Las miniaturas se generan con `wsrv.nl`, que redimensiona imágenes públicas. El fondo completo se descarga de GitHub solo al aplicarlo.

## Seguridad y reversibilidad

- Antes de cambiar una clave del registro se exporta a `backups\<fecha>\*.reg`, y Windhawk se respalda con su propia exportación.
- Las descargas se verifican con SHA-256 si el origen lo publica; si no, por tamaño.
- La API de GitHub permite 60 consultas por hora, así que sus respuestas se guardan 24 h. Si se alcanza el límite, se descarga por enlace directo.
- Los cursores no ejecutan su `.inf` y las fuentes se instalan solo para tu usuario.

## Notas

- Algunos temas de Windhawk usan sus propios colores y pueden ignorar parte de los ajustes de color, transparencia o redondeo.
- Ocultar los widgets puede no estar permitido por registro en algunas versiones; el script avisa y sigue.
- Los fondos de la galería proceden de colecciones públicas de GitHub (`tokyo-night/wallpapers`, `dharmx/walls`, `orangci/walls-catppuccin-mocha`). Son para uso personal y sus derechos son de cada autor.

## Colores de la interfaz

La ventana de ZK-Custom usa los colores de la paleta que elijas y cambia al momento. Si aún no has elegido ninguna, toma el color de acento y el modo claro/oscuro de Windows.

## Vistas previas y pruebas

- **Todas las opciones tienen vista previa.** Los 175 packs de iconos muestran sus iconos reales, extraídos del propio pack con `catalog\Build-IconPreviews.ps1`. Los cursores muestran sus punteros reales sobre fondo oscuro y claro (`catalog\Build-CursorPreviews.ps1`), y los dibujados por el mod se recrean con sus colores y brillo. Las opciones por defecto se muestran como «Como viene en Windows».
- **Cambios por sección:** elegir algo en una sección solo marca esa sección como pendiente, y al aplicar solo se reenvían a Windhawk los mods que cambiaron. Cambiar la paleta solo vuelve a marcar las secciones donde activaste «Usar los colores de mi paleta».
## Orbs, fondos animados y perfiles

- **DeviantArt desde la app:** en *Botón Inicio → Ajustes* escribes un personaje, juego o marca y los resultados aparecen como tarjetas. Al elegir uno se descarga, se convierte en orb y se guarda en *Mis orbs*. Las tiras clásicas de 3 estados (normal, al pasar el ratón y pulsado) se separan solas. *Mis orbs* queda solo en tu equipo y no se sube al repositorio.
- **Convertidor:** cualquier imagen que importes se convierte en orb. Si tiene fondo transparente se respeta su forma; si no, se mete en una esfera con aro y reflejo.
- **Fondos animados y salvapantallas:** Lively Wallpaper se maneja en segundo plano, sin ventana, y arranca con Windows. El mismo fondo animado puede usarse como salvapantallas tras los minutos que elijas.
- **Mis perfiles:** guarda tu estilo completo con un nombre, vuelve a él con un clic y expórtalo o impórtalo como archivo (`profiles\`).