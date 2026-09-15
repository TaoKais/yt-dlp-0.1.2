# Git Secure Workspace para Windows

Utilidades PowerShell para trabajar con datos temporales y conservar el
resultado persistente dentro de archivos RAR5 cifrados. El proyecto está
orientado a Windows 10 y Windows 11 y utiliza programas instalados en el equipo,
sin reemplazar Git, `yt-dlp` ni WinRAR.

> **Estado del proyecto:** prototipo en desarrollo. `yt-list-lock` ya está
> disponible; la capa completa para bloquear y desbloquear repositorios Git aún
> está en fase de diseño. No utilice esta versión como única copia de datos
> importantes.

La secuencia completa, sus invariantes de seguridad y las pruebas de recuperación
se documentan en [docs/METODOLOGIA.md](docs/METODOLOGIA.md).

## Qué hace actualmente

El comando `yt-list-lock` recibe una o varias URL de canales o listas, solicita
a `yt-dlp` un índice plano y guarda líneas con este formato:

```text
Título del vídeo | https://www.youtube.com/watch?v=identificador
```

Después coloca el texto dentro de una carpeta temporal, crea un archivo RAR5
cifrado con WinRAR, prueba la integridad del RAR y elimina el workspace solo si
todo ha finalizado correctamente.

```text
URL de canal o lista
        │
        ▼
yt-dlp --flat-playlist --print ...
        │
        ▼
archivo de texto en %TEMP%\YtListLock-<id>
        │
        ▼
WinRAR a -ma5 -hp ... nombre.tmp.rar
        │
        ▼
WinRAR t -hp ... nombre.tmp.rar
        │
        ├── error: conservar workspace y RAR temporal
        │
        └── correcto: publicar nombre.rar y limpiar workspace
```

`--flat-playlist` evita procesar o descargar los archivos multimedia. La salida
contiene únicamente los títulos e identificadores que `yt-dlp` pueda consultar.

## Requisitos

- Windows 10 u 11.
- Windows PowerShell 5.1 o una versión posterior compatible.
- `yt-dlp.exe` instalado y accesible mediante `PATH`.
- WinRAR o Rar para Windows con soporte RAR5.
- Acceso legítimo a las URL consultadas.

La detección busca primero los ejecutables mediante `PATH` y después estas
ubicaciones habituales:

```text
C:\Program Files\WinRAR\WinRAR.exe
C:\Program Files\WinRAR\Rar.exe
C:\Program Files (x86)\WinRAR\WinRAR.exe
```

En el entorno de desarrollo se ha detectado WinRAR 7.23 en:

```text
C:\Program Files\WinRAR\WinRAR.exe
```

WinRAR es software de terceros y no se distribuye con este repositorio.

## Uso rápido

Desde la raíz del proyecto:

```powershell
.\tools\yt-list-lock.ps1 `
  -Source "https://www.youtube.com/@canal" `
  -Output "canal.txt" `
  -Folder "resultados\canal" `
  -ArchiveName "canal"
```

También se incluye un lanzador para CMD:

```bat
scripts\yt-list-lock.cmd -Source "https://www.youtube.com/@canal" -Output "canal.txt" -Folder "resultados\canal" -ArchiveName "canal"
```

El directorio padre indicado en `-Folder` debe existir. En el ejemplo anterior
el archivo final será:

```text
resultados\canal.rar
```

y el RAR contendrá:

```text
canal\canal.txt
```

## Varios canales o listas

La forma más sencilla desde una terminal consiste en separar las URL con `;`
dentro de una única cadena entre comillas:

```powershell
.\tools\yt-list-lock.ps1 `
  -Source "https://www.youtube.com/@canal;https://www.youtube.com/@canal2" `
  -Output "canales.txt" `
  -Folder "resultados\canalx" `
  -ArchiveName "mis-canales"
```

También se puede pasar un array desde PowerShell:

```powershell
$channels = @(
  'https://www.youtube.com/@canal'
  'https://www.youtube.com/@canal2'
)

.\tools\yt-list-lock.ps1 `
  -Source $channels `
  -Output "canales.txt" `
  -Folder "resultados\canalx" `
  -ArchiveName "mis-canales"
```

El comando elimina URL duplicadas conservando el orden y rechaza valores que no
sean direcciones HTTP o HTTPS absolutas. Las rutas con espacios deben escribirse
entre comillas.

## Parámetros

| Parámetro | Obligatorio | Descripción |
| --- | --- | --- |
| `-Source` | Sí | URL, array de URL o cadena de URL separadas por `;`. |
| `-Output` | Sí | Nombre del texto dentro del RAR. No admite una ruta. |
| `-Folder` | Sí | Ruta cuya última carpeta se reproducirá dentro del RAR. Su directorio padre será la ubicación del archivo cifrado. |
| `-ArchiveName` | Sí | Nombre del RAR, sin ruta. La extensión `.rar` es opcional. |
| `-ReplaceExisting` | No | Permite reemplazar transaccionalmente un RAR, conservando antes el anterior como `.previous.rar`. |

El módulo ofrece además `-YtDlpPath` y `-WinRARPath` para integraciones que
necesiten rutas explícitas:

```powershell
Import-Module .\tools\YtListLock.psm1 -Force

Invoke-YtListLock `
  -Source 'https://www.youtube.com/@canal' `
  -Output 'canal.txt' `
  -Folder 'C:\Listados\canal' `
  -ArchiveName 'canal' `
  -YtDlpPath 'C:\Tools\yt-dlp.exe' `
  -WinRARPath 'C:\Program Files\WinRAR\WinRAR.exe'
```

## Contraseña y cifrado

La contraseña no forma parte de la sintaxis del comando. No se admite
`nombre/password`, `-Password` ni una variable de configuración con el secreto.
Estas alternativas podrían revelar la contraseña mediante el historial, los
logs o los argumentos visibles del proceso.

El módulo invoca WinRAR con `-hp` sin añadir una contraseña:

```text
WinRAR.exe a -ma5 -hp -ep1 -- nombre.tmp.rar carpeta
WinRAR.exe t -hp -- nombre.tmp.rar
```

- `-ma5` solicita el formato RAR5.
- `-hp` solicita cifrado de datos y cabeceras y hace que WinRAR pida la
  contraseña interactivamente.
- `-ep1` evita almacenar innecesariamente la ruta completa de origen.
- `t` prueba el archivo cifrado antes de publicarlo.

WinRAR puede pedir la contraseña nuevamente durante la verificación. No cierre
esa segunda solicitud: sin una prueba correcta el RAR temporal no se convierte
en el archivo definitivo.

La interacción exacta de `-hp` depende de la versión y del ejecutable de
WinRAR. Debe comprobarse manualmente en el equipo antes de confiar información
importante al prototipo.

## Protección frente a sobrescrituras

El comando nunca sobrescribe silenciosamente un archivo existente.

Si `canal.rar` ya existe, la ejecución se detiene. Para sustituirlo de forma
explícita:

```powershell
.\tools\yt-list-lock.ps1 `
  -Source "https://www.youtube.com/@canal" `
  -Output "canal.txt" `
  -Folder "resultados\canal" `
  -ArchiveName "canal" `
  -ReplaceExisting
```

El orden de la operación es:

1. Crear `canal.tmp.rar`.
2. Verificar `canal.tmp.rar` con WinRAR.
3. Mover el RAR anterior a `canal.previous.rar`.
4. Mover el archivo verificado a `canal.rar`.
5. Eliminar el workspace temporal.

Si `canal.previous.rar` ya existe, la operación se detiene para evitar que
también esa copia sea sobrescrita.

## Fallos y recuperación

El workspace se crea bajo una ruta similar a:

```text
%TEMP%\YtListLock-0123456789abcdef...
```

Se conserva cuando falla cualquiera de estas operaciones:

- consulta de `yt-dlp`;
- generación del archivo de texto;
- creación del RAR;
- contraseña incorrecta o diálogo cancelado;
- verificación del archivo cifrado;
- movimiento transaccional del resultado.

PowerShell muestra la ubicación conservada mediante una advertencia. Revise
manualmente su contenido antes de repetir el comando. Si encuentra un
`nombre.tmp.rar`, no lo borre hasta determinar si contiene la única copia útil.

La salida de error de `yt-dlp` se conserva dentro de la sesión como
`yt-dlp.stderr.txt`. No incluye contraseñas introducidas en WinRAR, pero podría
contener URL o información de diagnóstico de la consulta.

## Consultar disponibilidad

```powershell
Import-Module .\tools\YtListLock.psm1 -Force
Get-YtListLockStatus | Format-List
```

Ejemplo:

```text
YtDlp  : C:\...\yt-dlp.exe
WinRAR : C:\Program Files\WinRAR\WinRAR.exe
```

Un campo vacío significa que el programa correspondiente no ha sido localizado.

## Pruebas

Las pruebas actuales no acceden a YouTube ni introducen contraseñas. Validan el
parsing de múltiples URL, la eliminación de duplicados, el rechazo de entradas
inválidas y la detección local de `yt-dlp`:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\tests\YtListLock.Tests.ps1
```

La creación real de un RAR cifrado y el diálogo interactivo de WinRAR siguen
requiriendo una prueba manual de integración.

## Objetivo futuro: repositorios Git cifrados

El objetivo general es construir una capa alrededor de Git que permita mantener
la copia persistente de un repositorio dentro de un RAR5 cifrado:

```text
GitHub o remoto Git
        ↓ HTTPS o SSH
workspace temporal (%TEMP% o RAM Disk)
        ↕
repositorio completo cifrado, incluido .git
```

Git seguirá realizando `clone`, `fetch`, `pull`, `rebase`, `commit` y `push`.
La utilidad administrará únicamente el workspace temporal, el cifrado, la
verificación y la recuperación ante fallos. Están previstos `git-lock`,
`git-unlock`, `git-work` y `git-lock-status`, pero aún no están implementados.

HTTPS y SSH cifran el transporte hacia el remoto. RAR5 persigue un objetivo
diferente: proteger la copia mientras permanece almacenada localmente y el
workspace está cerrado.

Cuando exista un repositorio original verificable se utilizará:

```text
origin    → fork o repositorio de trabajo
upstream  → repositorio original, solo como referencia
```

Nunca se harán envíos al remoto `upstream`.

## Uso legítimo y límites

Este proyecto **no es una herramienta para descargar, extraer, copiar ni
sustraer música, vídeo u otros contenidos multimedia**. No incorpora mecanismos
para eludir controles de acceso, medidas técnicas de protección, licencias,
derechos de autor o condiciones de servicio.

`yt-list-lock` se limita a solicitar un índice de títulos y enlaces mediante el
modo plano de `yt-dlp`. Cada usuario debe tener autorización para consultar las
fuentes y tratar los datos resultantes, y es responsable de cumplir la
legislación, las licencias y las condiciones aplicables.

El nombre actual del repositorio no implica afiliación, patrocinio ni respaldo
por parte de `yt-dlp`, sus mantenedores, YouTube, Google ni ninguna empresa o
marca. El proyecto no comercializa música o contenido multimedia, no actúa en
nombre de terceros y no utiliza `yt-dlp` como motor de descarga.

## Estructura del repositorio

```text
tools/
  YtListLock.psm1       funciones de detección, parsing y cifrado
  yt-list-lock.ps1      comando PowerShell
scripts/
  yt-list-lock.cmd      lanzador para CMD
tests/
  YtListLock.Tests.ps1  pruebas locales sin descarga multimedia
LICENSE
README.md
```

## Licencia

Consulte [LICENSE](LICENSE).
