# Diario de diseño · ZK-Custom

Registro de las decisiones tomadas, para saber por qué el tema es como es.

## Equipo de origen (11/11/2026)

| Elemento | Valor |
|---|---|
| Sistema | Windows 11 Pro 26H2, build 26300 |
| GPU | Intel UHD + RTX 4060 Laptop |
| Pantalla | 2560×1600 a 240 Hz (escalado ~150 %) |
| CPU / RAM | i7-13650HX · 16 GB |

## Decisiones

| # | Tema | Elección | Motivo / notas |
|---|---|---|---|
| 1 | Estilo | Cyberpunk | Elegido entre Minimal, Cyberpunk y Cupertino |
| 2 | Paleta | Tokyo Night | Más suave que Synthwave para muchas horas de uso |
| 3 | Fondo | Estático | Sin consumo extra de batería ni GPU |
| 4 | Barra de tareas | Transparente, centrada y muy personalizada | Windhawk + Windows 11 Taskbar Styler (ExplorerPatcher no, por inestable en 26H2) |
| 5 | Widgets | Ninguno | Sin Rainmeter: escritorio limpio, la personalización va a la barra de tareas |
| 6 | Motor de iconos | Windhawk Resource Redirect | No modifica archivos del sistema y es reversible desactivando el mod |
| 7 | Formato del proyecto | Asistente gráfico (WPF) + instalador | Elegir viendo capturas y probar paso a paso; `config.json` sigue siendo la fuente para otros equipos |
| 8 | Catálogo de opciones | Generado desde los repos oficiales de Windhawk + listas curadas | Datos estructurados (ajustes de cada mod y guías de estilos con capturas); no se leen webs libres |
| 9 | Automatización de Windhawk | Solo `windhawk-cli` (2.x) | El modo guiado se quitó (12/11/2026): no aplicaba nada por sí solo |
| 10 | Cursores | Leer el `.inf` del pack, no ejecutarlo | El `.inf` de Bibata añade una entrada `RunOnce` en HKLM; así solo se tocan las claves del usuario |
| 11 | Windhawk visible | Oculto | Sin icono en la bandeja ni ventanas; los cambios se hacen en segundo plano |
| 12 | Nombre | ZK-Custom | Antes WinRice |
| 13 | Más opciones | 25 paletas variadas, 6 categorías nuevas, galería de 600 fondos | Notificaciones, app Configuración, efectos de ventana, esquinas, estela del ratón, reloj y ajustes del sistema |
| 14 | Opciones sin captura | Descripción en español, vista simulada o «Ver ejemplos» | Efectos, esquinas, estelas, reloj y fuentes se dibujan en la tarjeta; el resto enlaza a su guía o a imágenes |
| 15 | Interfaz | Registro en un panel lateral derecho y captura ampliada al pasar el ratón | Las miniaturas eran pequeñas y el registro inferior quitaba espacio |
| 16 | Interfaz v2 | Escritorio simulado en vivo + temas listos de un clic | Se ve el conjunto antes de aplicar; se aplica todo de una vez |
| 17 | Ajustar estilos | Modo básico (paleta, acento, transparencia, redondeo) y avanzado (fondo, borde, texto) | Se traducen a estilos de Windhawk que se suman al tema elegido |
| 18 | Sistemas | Solo Windows 11 | Los estilos de barra, Inicio y Explorador son exclusivos de 11; Windows 10 ya no tiene soporte |
| 19 | Arranque | `ZK-Custom.exe` con icono propio | Compilado con el C# de Windows; pide administrador y abre el asistente sin consola |
| 20 | Iconos | Cambio de pack sin aviso | Se cierra el Explorador, se cambia el pack, se vacía la caché y se reabre |
| 21 | Solo visual | Se quitaron ajustes no visuales | Búsqueda de Bing, «Finalizar tarea», menús rápidos, etc. no son estética |
| 23 | Orbs del botón Inicio | Dibujados por ZK-Custom + orbs de paleta + subir los tuyos | No dependen de webs de terceros; el mod Start Button Replacer los lee desde %APPDATA%\ZK-Custom\orbs |
| 24 | Vista previa de ajustes | Inicio, notificaciones, Explorador, Configuración y terminal simulados con tus ajustes | Antes, cambiar un ajuste no se veía porque la captura del tema tapaba la vista |
| 25 | Orbs de personajes | Biblioteca «Mis orbs» + buscador | No se dibujan personajes con derechos de autor; tú importas los que descargues |
| 26 | Colores de la interfaz | Siguen la paleta elegida (o Windows si no hay) | La app se ve integrada con tu personalización |
| 27 | Extras | Fondos animados (Lively), día y noche, carpetas de colores | Lo visual que faltaba; se descartan fuente del sistema y logo de arranque por riesgo |
| 28 | Repositorio | GitHub privado | Uso personal; incluye fondos y orbs de terceros |
| 22 | Categorías nuevas | Tamaño de barra, botón Inicio, bordes, menús, selección, reloj de bloqueo | Mods de Windhawk con vista simulada o capturas reales |

## Paleta

| Rol | Hex |
|---|---|
| Fondo | `#1A1B26` |
| Superficie | `#24283B` |
| Texto | `#C0CAF5` |
| Atenuado | `#565F89` |
| Acento | `#7AA2F7` |
| Secundario | `#BB9AF7` |
| Detalle | `#7DCFFF` |

## Pendiente de decidir

Se elige en el asistente (`ZK-Custom.exe`), que guarda las elecciones en `config.json` → `wizard.selections` y `wizard.options`.

- [ ] Elegir un tema listo o cada sección, y aplicarlo a este equipo

## Contenido de terceros (noviembre 2026)

- **VSThemes fuera:** no tiene API, bloquea a los bots (429) y muchos packs traen instaladores `.exe`. Descartado.
- **Wallhaven dentro:** API pública y estable (45 peticiones por minuto sin clave). Solo `purity=100` (apto para todos) y `atleast=1920x1080`. Su filtro de color admite una lista fija de 29 colores, así que se usa el más cercano al principal de la paleta.
- **Cursores de GitHub:** BreezeX, Notwaita, Capitaine (8 variantes) y AOSP traen versión para Windows con `install.inf`. Se lee el `.inf` sin ejecutarlo; si hay varios, se prefiere `install.inf` antes que las variantes (`Install_1x.inf`). Nunca se ejecutan `.exe` de los packs.
