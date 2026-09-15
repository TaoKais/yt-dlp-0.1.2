Set-StrictMode -Version Latest

function Resolve-YtListExecutable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $Names,
        [string[]] $KnownPaths = @()
    )

    foreach ($name in $Names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { return $command.Source }
    }

    foreach ($path in $KnownPaths) {
        if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $path).Path
        }
    }

    return $null
}

function ConvertTo-YtListSources {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string[]] $Source)

    $sources = foreach ($entry in $Source) {
        foreach ($part in $entry.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)) {
            $candidate = $part.Trim()
            if (-not $candidate) { continue }

            $uri = $null
            if (-not [Uri]::TryCreate($candidate, [UriKind]::Absolute, [ref] $uri) -or
                $uri.Scheme -notin @('http', 'https')) {
                throw "Origen no valido: '$candidate'. Solo se admiten URL HTTP o HTTPS absolutas."
            }
            $candidate
        }
    }

    $result = @($sources | Select-Object -Unique)
    if ($result.Count -eq 0) { throw 'Debe indicar al menos un origen.' }
    return $result
}

function Get-YtListLockStatus {
    [CmdletBinding()]
    param()

    $programFiles = [Environment]::GetFolderPath('ProgramFiles')
    $programFilesX86 = [Environment]::GetFolderPath('ProgramFilesX86')
    [pscustomobject]@{
        YtDlp = Resolve-YtListExecutable -Names @('yt-dlp.exe', 'yt-dlp')
        WinRAR = Resolve-YtListExecutable -Names @('WinRAR.exe', 'Rar.exe') -KnownPaths @(
            (Join-Path $programFiles 'WinRAR\WinRAR.exe'),
            (Join-Path $programFiles 'WinRAR\Rar.exe'),
            $(if ($programFilesX86) { Join-Path $programFilesX86 'WinRAR\WinRAR.exe' })
        )
    }
}

function Invoke-WinRARProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $WinRARPath,
        [Parameter(Mandatory)] [ValidateSet('a', 't')] [string] $Command,
        [Parameter(Mandatory)] [string] $ArchivePath,
        [string] $InputPath
    )

    # These paths cannot contain a double quote on Windows. Quoting them here
    # preserves spaces without ever adding a password to the process arguments.
    $arguments = if ($Command -eq 'a') {
        'a -ma5 -hp -ep1 -- "{0}" "{1}"' -f $ArchivePath, $InputPath
    }
    else {
        't -hp -- "{0}"' -f $ArchivePath
    }

    $process = Start-Process -FilePath $WinRARPath -ArgumentList $arguments -Wait -PassThru
    return $process.ExitCode
}

function Invoke-YtListLock {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)] [string[]] $Source,
        [Parameter(Mandatory)] [string] $Output,
        [Parameter(Mandatory)] [string] $Folder,
        [Parameter(Mandatory)] [string] $ArchiveName,
        [switch] $ReplaceExisting,
        [string] $YtDlpPath,
        [string] $WinRARPath
    )

    $sources = ConvertTo-YtListSources -Source $Source
    $status = Get-YtListLockStatus
    if (-not $YtDlpPath) { $YtDlpPath = $status.YtDlp }
    if (-not $WinRARPath) { $WinRARPath = $status.WinRAR }
    if (-not $YtDlpPath) { throw 'No se encontro yt-dlp. Instalelo o indique -YtDlpPath.' }
    if (-not $WinRARPath) { throw 'No se encontro WinRAR.exe o Rar.exe. Instalelo o indique -WinRARPath.' }

    $targetFolder = [IO.Path]::GetFullPath($Folder)
    $outputName = [IO.Path]::GetFileName($Output)
    if (-not $outputName -or $outputName -ne $Output) {
        throw '-Output debe ser unicamente un nombre de archivo, no una ruta.'
    }

    $archiveLeaf = [IO.Path]::GetFileName($ArchiveName)
    if ($archiveLeaf -ne $ArchiveName) { throw '-ArchiveName no puede incluir una ruta.' }
    if (-not $archiveLeaf.EndsWith('.rar', [StringComparison]::OrdinalIgnoreCase)) {
        $archiveLeaf += '.rar'
    }

    $parent = Split-Path -Parent $targetFolder
    if (-not $parent) { $parent = (Get-Location).Path }
    if (Test-Path -LiteralPath $parent) {
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            throw "La ruta de salida existe, pero no es un directorio: '$parent'."
        }
    }
    else {
        New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop | Out-Null
    }

    $archivePath = Join-Path $parent $archiveLeaf
    $tempArchivePath = Join-Path $parent ($archiveLeaf -replace '\.rar$', '.tmp.rar')
    $previousArchivePath = Join-Path $parent ($archiveLeaf -replace '\.rar$', '.previous.rar')
    Write-Verbose "Archivo RAR de destino: $archivePath"

    if (Test-Path -LiteralPath $tempArchivePath) {
        throw "Existe un archivo temporal previo: '$tempArchivePath'. Reviselo manualmente."
    }
    if ((Test-Path -LiteralPath $archivePath) -and -not $ReplaceExisting) {
        throw "El archivo '$archivePath' ya existe. Use -ReplaceExisting para conservarlo como .previous.rar."
    }
    if ($ReplaceExisting -and (Test-Path -LiteralPath $previousArchivePath)) {
        throw "Ya existe '$previousArchivePath'. No se sobrescribira."
    }

    $sessionRoot = Join-Path ([IO.Path]::GetTempPath()) ('YtListLock-' + [Guid]::NewGuid().ToString('N'))
    $stagedFolder = Join-Path $sessionRoot ([IO.Path]::GetFileName($targetFolder))
    $stagedOutput = Join-Path $stagedFolder $outputName
    $errorFile = Join-Path $sessionRoot 'yt-dlp.stderr.txt'
    $succeeded = $false

    New-Item -ItemType Directory -Path $stagedFolder -Force | Out-Null
    try {
        $arguments = @('--flat-playlist', '--print', '%(title)s | https://www.youtube.com/watch?v=%(id)s') + $sources
        $lines = & $YtDlpPath @arguments 2> $errorFile
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            throw "yt-dlp termino con codigo $exitCode. Workspace conservado en '$sessionRoot'."
        }
        @($lines) | Set-Content -LiteralPath $stagedOutput -Encoding UTF8
        if (-not (Test-Path -LiteralPath $stagedOutput -PathType Leaf)) {
            throw "No se genero '$stagedOutput'."
        }

        if (-not $PSCmdlet.ShouldProcess($archivePath, 'Crear y verificar archivo RAR5 cifrado')) { return }

        $rarExitCode = Invoke-WinRARProcess -WinRARPath $WinRARPath -Command a `
            -ArchivePath $tempArchivePath -InputPath $stagedFolder
        if ($rarExitCode -ne 0 -or -not (Test-Path -LiteralPath $tempArchivePath -PathType Leaf)) {
            throw "WinRAR no pudo crear el archivo. Workspace conservado en '$sessionRoot'."
        }

        $rarExitCode = Invoke-WinRARProcess -WinRARPath $WinRARPath -Command t `
            -ArchivePath $tempArchivePath
        if ($rarExitCode -ne 0) {
            throw "La verificacion del RAR fallo. Workspace y archivo temporal conservados."
        }

        if (Test-Path -LiteralPath $archivePath) {
            Move-Item -LiteralPath $archivePath -Destination $previousArchivePath
        }
        Move-Item -LiteralPath $tempArchivePath -Destination $archivePath
        $succeeded = $true
        [pscustomobject]@{ Archive = $archivePath; Sources = $sources.Count; Output = $outputName }
    }
    finally {
        if ($succeeded -and (Test-Path -LiteralPath $sessionRoot)) {
            Remove-Item -LiteralPath $sessionRoot -Recurse -Force
        }
        elseif (Test-Path -LiteralPath $sessionRoot) {
            Write-Warning "La sesion temporal se conserva para recuperacion: $sessionRoot"
        }
    }
}

Export-ModuleMember -Function ConvertTo-YtListSources, Get-YtListLockStatus, Invoke-YtListLock
