[CmdletBinding()]
param(
    [string] $Destination
)

$Destination = if ($Destination) { $Destination } else { Join-Path $PSScriptRoot '..\test-output' }
$destinationPath = [IO.Path]::GetFullPath($Destination)
if (-not (Test-Path -LiteralPath $destinationPath -PathType Container)) {
    New-Item -ItemType Directory -Path $destinationPath | Out-Null
}

Import-Module (Join-Path $PSScriptRoot '..\tools\YtListLock.psm1') -Force
Invoke-YtListLock `
    -Source 'https://www.youtube.com/watch?v=TEST_ID' `
    -Output 'indice-prueba.txt' `
    -Folder (Join-Path $destinationPath 'contenido') `
    -ArchiveName 'integration-test' `
    -YtDlpPath (Join-Path $PSScriptRoot 'fixtures\fake-yt-dlp.cmd') `
    -WinRARPath 'C:\Program Files\WinRAR\WinRAR.exe'
