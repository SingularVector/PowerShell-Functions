#Requires -Version 7.4
[CmdletBinding(SupportsShouldProcess)]
param (
    [string]$Destination = (Join-Path $PSScriptRoot '../.eml-dependencies/MimeKitLite/4.18.1')
)

$ErrorActionPreference = 'Stop'
$uri = 'https://api.nuget.org/v3-flatcontainer/mimekitlite/4.18.1/mimekitlite.4.18.1.nupkg'
$expectedHash = '6cc85bb8dfcd3680226082dbf79cd0ac27442ead35a8e75aa1be7b80acc8f28c'
$destinationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
if (-not $PSCmdlet.ShouldProcess($destinationPath, 'Download and install pinned MimeKitLite 4.18.1 from NuGet')) { return }
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('eml-dependency-' + [guid]::NewGuid().ToString('N'))
try
{
    [void][System.IO.Directory]::CreateDirectory($temp)
    $package = Join-Path $temp 'mimekitlite.nupkg'
    Invoke-WebRequest -Uri $uri -OutFile $package -ErrorAction Stop
    if ((Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash -ine $expectedHash)
    {
        throw 'MimeKitLite package checksum mismatch; nothing was installed.'
    }
    $archive = [System.IO.Compression.ZipFile]::OpenRead($package)
    try
    {
        $entry = $archive.GetEntry('lib/net8.0/MimeKitLite.dll')
        if ($null -eq $entry) { throw 'Expected net8.0 assembly is absent from package.' }
        $staged = Join-Path $temp 'MimeKitLite.dll'
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $staged)
    }
    finally { $archive.Dispose() }
    [void][System.IO.Directory]::CreateDirectory($destinationPath)
    Copy-Item -LiteralPath $staged -Destination (Join-Path $destinationPath 'MimeKitLite.dll') -Force
    # Retain the original NuGet archive, including its nuspec and upstream licensing metadata.
    Copy-Item -LiteralPath $package -Destination (Join-Path $destinationPath 'MimeKitLite.4.18.1.nupkg') -Force
    Write-Output (Join-Path $destinationPath 'MimeKitLite.dll')
}
finally
{
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
