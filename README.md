# Git Secure Workspace para Windows

Proyecto en fase inicial para crear una pequeña capa de seguridad alrededor de
Git en Windows 10 y Windows 11. Su objetivo es mantener cifrada la copia
persistente de un repositorio y utilizar un espacio temporal únicamente durante
la sesión de trabajo.

## Objetivo

La utilidad permitirá clonar o abrir un repositorio Git dentro de un directorio
temporal, trabajar con las herramientas habituales (`git`, un editor o Codex) y
guardar después el repositorio completo —incluido `.git`— en un archivo RAR5
protegido mediante AES-256 y cifrado de cabeceras.

Git seguirá siendo responsable de las operaciones de red y del historial:

- `clone`, `fetch`, `pull` y `rebase`;
- `status`, `commit` y gestión de ramas;
- `push` hacia los remotos autorizados.

Esta capa se limitará a gestionar el ciclo:

```text
repositorio remoto
        ↓ Git mediante HTTPS o SSH
workspace temporal (%TEMP% o RAM Disk)
        ↕
archivo RAR5 cifrado almacenado localmente
```

HTTPS y SSH protegen el transporte. El cifrado RAR5 propuesto tiene un objetivo
distinto: proteger la copia del repositorio mientras permanece almacenada
localmente y el workspace está cerrado.

## Alcance previsto

La primera implementación se desarrollará principalmente en PowerShell e
incluirá, de forma incremental:

- `git-lock`: clonar un repositorio y crear un archivo cifrado verificado;
- `git-unlock`: extraer un repositorio en un workspace temporal;
- detección de Git, WinRAR/Rar y PowerShell;
- soporte posterior para `git-work`, estado no sensible, RAM Disk y recuperación
  de sesiones interrumpidas;
- sustitución transaccional del archivo cifrado, sin sobrescrituras silenciosas;
- conservación del workspace si falla Git, WinRAR o la validación del archivo.

La contraseña no deberá almacenarse en Git, archivos de configuración o logs,
ni mostrarse en pantalla. Antes de implementar el manejo de credenciales se
validará el comportamiento real de WinRAR con la solicitud interactiva `-hp`,
evitando siempre que sea posible incluir secretos en la línea de comandos del
proceso.

## Uso legítimo y límites del proyecto

Este proyecto **no es una herramienta para descargar, extraer, copiar ni
sustraer música, vídeo u otros contenidos multimedia**. Tampoco añadirá métodos
para eludir controles de acceso, medidas técnicas de protección, licencias,
derechos de autor ni condiciones de servicio de plataformas de terceros.

La utilidad se diseña exclusivamente para proteger repositorios Git locales que
el usuario tenga derecho a utilizar y administrar. Cada usuario es responsable
de disponer de autorización sobre el código, los remotos y los datos incluidos
en el repositorio, así como de cumplir la legislación y las licencias aplicables.

El nombre actual del repositorio no supone afiliación, patrocinio ni respaldo
por parte del proyecto `yt-dlp`, sus mantenedores o cualquier empresa, marca o
servicio comercial. Esta iniciativa no comercializa música ni contenido
multimedia, no actúa en nombre de ninguna marca y no utiliza `yt-dlp` como motor
de descarga. Para evitar confusión, se podrá adoptar un nombre definitivo
centrado en su función, por ejemplo **Git Secure Workspace**.

## Estado

El proyecto se encuentra en fase de análisis y diseño. Todavía no contiene una
implementación operativa ni debe considerarse apto para proteger información
crítica. El diseño de seguridad, el tratamiento de interrupciones y las pruebas
de recuperación deberán revisarse antes de publicar una primera versión
utilizable.

## Índices de canales: `yt-list-lock`

El prototipo incluye un comando independiente que usa `yt-dlp
--flat-playlist` únicamente para generar un índice de títulos y enlaces. No
descarga audio ni vídeo. Después cifra el archivo de texto mediante WinRAR en
formato RAR5 y verifica el archivo antes de eliminar el espacio temporal.

```powershell
.\tools\yt-list-lock.ps1 `
  -Source "https://www.youtube.com/@canal;https://www.youtube.com/@canal2" `
  -Output "canal.txt" `
  -Folder "folder\canalx" `
  -ArchiveName "nombre"
```

También se puede repetir `-Source` desde código PowerShell pasando un array. La
contraseña no se acepta como parámetro: WinRAR debe solicitarla
interactivamente mediante `-hp` sin valor. Nunca utilice una sintaxis como
`nombre/password`, porque expondría el secreto en el historial y posiblemente
en la lista de procesos.

Si el RAR de destino existe, el comando se detiene. Con `-ReplaceExisting`, la
versión anterior se conserva como `nombre.previous.rar`, siempre que ese backup
no exista ya. Cualquier fallo de `yt-dlp`, WinRAR o la verificación conserva el
workspace temporal para recuperación.

WinRAR no se distribuye con este repositorio. La interacción de contraseña debe
validarse con la versión concreta instalada antes de confiar datos importantes
al prototipo.

## Colaboración con un repositorio original

Cuando el proyecto se base en otro repositorio, se mantendrá esta convención:

```text
origin    → fork o repositorio de trabajo
upstream  → repositorio original, solo como referencia de colaboración
```

No se realizarán envíos al remoto `upstream`. La sincronización prevista será
mediante `git fetch upstream` y el rebase sobre la rama principal que utilice el
proyecto original.

## Licencia

Consulta el archivo [LICENSE](LICENSE).
