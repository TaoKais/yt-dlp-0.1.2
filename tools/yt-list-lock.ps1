[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0)] [string[]] $Source,
    [Parameter(Mandatory)] [string] $Output,
    [Parameter(Mandatory)] [string] $Folder,
    [Parameter(Mandatory)] [string] $ArchiveName,
    [switch] $ReplaceExisting
)

Import-Module (Join-Path $PSScriptRoot 'YtListLock.psm1') -Force
Invoke-YtListLock @PSBoundParameters
