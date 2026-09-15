$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\tools\YtListLock.psm1') -Force

function Assert-Equal($Expected, $Actual, [string] $Message) {
    if ($Expected -ne $Actual) { throw "$Message Esperado='$Expected'; real='$Actual'." }
}

$sources = @(ConvertTo-YtListSources -Source @(
    'https://www.youtube.com/@canal; https://www.youtube.com/@canal2',
    'https://www.youtube.com/@canal'
))
Assert-Equal 2 $sources.Count 'Debe separar por punto y coma y eliminar duplicados.'
Assert-Equal 'https://www.youtube.com/@canal2' $sources[1] 'Debe conservar el orden.'

$rejected = $false
try { ConvertTo-YtListSources -Source 'not-a-url' | Out-Null } catch { $rejected = $true }
Assert-Equal $true $rejected 'Debe rechazar orígenes no HTTP(S).'

$status = Get-YtListLockStatus
if (-not $status.YtDlp) { throw 'La prueba esperaba encontrar yt-dlp en este equipo.' }

Write-Output 'YtListLock.Tests.ps1: OK'
