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

$singleSource = @(ConvertTo-YtListSources -Source 'https://example.invalid/source')
Assert-Equal 1 $singleSource.Count 'Una sola fuente debe conservarse como colección.'
Assert-Equal 'https://example.invalid/source' $singleSource[0] 'Debe conservar la fuente única.'

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('YtListLock-Unit-' + [Guid]::NewGuid().ToString('N'))
try {
    $result = Invoke-YtListLock `
        -Source 'https://example.invalid/source' `
        -Output 'single.txt' `
        -Folder (Join-Path $testRoot 'output\single') `
        -ArchiveName 'single-source' `
        -YtDlpPath (Join-Path $PSScriptRoot 'fixtures\fake-yt-dlp.cmd') `
        -WinRARPath (Join-Path $PSScriptRoot 'fixtures\fake-winrar.cmd')
    Assert-Equal 1 $result.Sources 'Invoke-YtListLock debe informar una sola fuente sin error de Count.'
    Assert-Equal $true (Test-Path -LiteralPath $result.Archive -PathType Leaf) 'Debe publicar el RAR simulado.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

$rejected = $false
try { ConvertTo-YtListSources -Source 'not-a-url' | Out-Null } catch { $rejected = $true }
Assert-Equal $true $rejected 'Debe rechazar orígenes no HTTP(S).'

$status = Get-YtListLockStatus
if (-not $status.YtDlp) { throw 'La prueba esperaba encontrar yt-dlp en este equipo.' }

Write-Output 'YtListLock.Tests.ps1: OK'
