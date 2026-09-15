# Metodología de funcionamiento y validación

Este documento describe cómo trabaja `yt-list-lock`, qué condiciones deben
cumplirse antes de publicar un RAR y cómo se recupera una ejecución fallida.
La regla central es sencilla: **los datos temporales solo se eliminan después de
crear y verificar correctamente el archivo cifrado**.

## 1. Límites de la operación

`yt-list-lock` crea un índice textual de títulos y enlaces. Ejecuta `yt-dlp` con
`--flat-playlist` y `--print`; no solicita la descarga de audio o vídeo. El
resultado se cifra para proteger el listado almacenado localmente.

Las conexiones HTTPS protegen el transporte. WinRAR protege posteriormente el
archivo local. Son dos controles diferentes y ninguno sustituye al otro.

## 2. Entradas

La operación recibe:

- una URL, un array de URL o varias URL separadas por `;`;
- el nombre del archivo de texto;
- la carpeta lógica que aparecerá dentro del RAR;
- el nombre del archivo RAR;
- opcionalmente, autorización explícita para sustituir un RAR anterior.

La contraseña no es una entrada del script. No se acepta mediante parámetros,
archivos de configuración ni variables de entorno.

## 3. Preparación y controles previos

Antes de consultar una URL, el módulo:

1. Separa las entradas delimitadas por `;`.
2. Elimina duplicados conservando el orden.
3. Comprueba que cada entrada sea una URL HTTP o HTTPS absoluta.
4. Localiza `yt-dlp.exe`.
5. Localiza `WinRAR.exe` o `Rar.exe`.
6. Calcula las rutas definitiva, temporal y de respaldo.
7. Se detiene si detecta un archivo que pudiera ser sobrescrito sin permiso.

Los nombres utilizados en la transacción son:

```text
nombre.rar           resultado definitivo
nombre.tmp.rar       candidato todavía no validado
nombre.previous.rar  versión anterior conservada
```

## 4. Workspace aislado

Cada ejecución crea un directorio con un identificador aleatorio:

```text
%TEMP%\YtListLock-<identificador>
```

En él se guarda la carpeta lógica, el índice de texto y el diagnóstico de
`yt-dlp`. El archivo `yt-dlp.stderr.txt` puede contener URL y mensajes técnicos,
pero no recibe la contraseña de WinRAR.

## 5. Creación del índice

La operación equivalente es:

```text
yt-dlp --flat-playlist --print "%(title)s | https://www.youtube.com/watch?v=%(id)s" URL...
```

PowerShell captura la salida directamente. No utiliza `>` proporcionado por el
usuario, lo que permite comprobar el código de salida antes de continuar. Si
`yt-dlp` falla, no se llama a WinRAR y el workspace se conserva.

## 6. Cifrado interactivo

WinRAR se ejecuta aproximadamente así:

```text
WinRAR.exe a -ma5 -hp -ep1 -- nombre.tmp.rar carpeta
```

La opción `-hp` se pasa sin contraseña. WinRAR solicita el secreto directamente
en su interfaz; el script no lo conoce, no lo imprime y no lo añade a los
argumentos del proceso.

El módulo espera a que la aplicación gráfica termine mediante
`Start-Process -Wait`. Esta espera es necesaria: una llamada directa a
`WinRAR.exe` puede devolver el control antes de que el archivo esté terminado.

## 7. Verificación obligatoria

Que exista `nombre.tmp.rar` no basta. Se inicia una segunda operación:

```text
WinRAR.exe t -hp -- nombre.tmp.rar
```

WinRAR puede pedir nuevamente la contraseña. La verificación solo se considera
correcta si el proceso finaliza con código cero. Una contraseña distinta, un
diálogo cancelado o un archivo corrupto impiden publicar el resultado.

## 8. Publicación transaccional

Sin un RAR anterior:

```text
nombre.tmp.rar → nombre.rar
```

Con `-ReplaceExisting`:

```text
nombre.rar     → nombre.previous.rar
nombre.tmp.rar → nombre.rar
```

La sustitución ocurre únicamente después de la prueba satisfactoria. Si ya
existe `nombre.previous.rar`, el comando se detiene para no destruirlo.

## 9. Limpieza y recuperación

El bloque `finally` aplica dos resultados posibles:

- éxito completo: elimina el workspace temporal;
- cualquier fallo: conserva el workspace y muestra su ubicación.

El RAR temporal tampoco se elimina tras una verificación fallida. Debe revisarse
manualmente porque puede ser la única copia cifrada creada durante la sesión.

No se debe automatizar la eliminación de sesiones abandonadas hasta disponer de
un inventario, una política de antigüedad y una confirmación expresa del usuario.

## 10. Metodología de pruebas

Las pruebas se dividen en dos grupos.

### Pruebas locales sin red

`tests/YtListLock.Tests.ps1` valida parsing, deduplicación, rechazo de URL no
válidas y detección de herramientas. `tests/fixtures/fake-yt-dlp.cmd` genera una
línea ficticia para probar WinRAR sin acceder a YouTube ni descargar contenido.

### Prueba interactiva de WinRAR

`tests/Invoke-WinRARIntegration.ps1` utiliza el fixture y exige que el usuario
introduzca la contraseña directamente en WinRAR. Nunca se debe escribir esa
contraseña en la terminal o incorporarla al script.

La prueba realizada con WinRAR 7.23 confirmó dos comportamientos:

1. WinRAR crea el candidato RAR5 cuando recibe `-ma5 -hp`.
2. Si se introducen deliberadamente contraseñas diferentes al crear y verificar,
   WinRAR devuelve el código 11, el resultado definitivo no se publica y los
   datos temporales permanecen disponibles para recuperación.

Esto valida el escenario de contraseña incorrecta y la política de no eliminar
datos después de un fallo. Aún debe ejecutarse el caso de éxito utilizando la
misma contraseña en ambos diálogos.

## 11. Fallos de red y certificados

Una prueba contra YouTube se detuvo porque `yt-dlp` no pudo validar la cadena de
certificados TLS del equipo. El proyecto no añade automáticamente
`--no-check-certificates`: continuar sin validar certificados debilitaría la
seguridad del transporte. En ese caso debe repararse primero el almacén de
certificados o la configuración de red.

## 12. Evidencias que nunca se publican

`test-output/`, los RAR temporales y los diagnósticos locales están excluidos por
`.gitignore`. Antes de cada commit se debe comprobar `git status` para evitar la
publicación accidental de índices, URL privadas o archivos cifrados de prueba.

## 13. Criterio de éxito

Una ejecución solo es satisfactoria cuando se cumplen todas estas condiciones:

- `yt-dlp` finaliza con código cero;
- se genera el índice esperado;
- WinRAR crea el candidato RAR5;
- WinRAR verifica el candidato con código cero;
- el candidato se mueve al nombre definitivo;
- cualquier versión anterior se conserva según la política elegida;
- el workspace se elimina únicamente al final.

Si falta una sola condición, el resultado se considera fallido y se prioriza la
recuperación sobre la limpieza.
