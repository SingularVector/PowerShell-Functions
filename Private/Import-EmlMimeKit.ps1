function Import-EmlMimeKit
{
    [CmdletBinding()]
    param ([Parameter(Mandatory)][string]$AssemblyPath)

    $expectedHash = '437939ba9f01228cc19dd9f755d5e77cac1fd44a8c2b076ed35b927aa625306c'
    if (-not (Test-Path -LiteralPath $AssemblyPath -PathType Leaf))
    {
        throw 'MimeKitLite dependency not found. Run ./scripts/Install-EmlDependency.ps1 once, or supply MimeKitPath. Parsing never downloads dependencies.'
    }
    $path = (Get-Item -LiteralPath $AssemblyPath -Force -ErrorAction Stop).FullName
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $expectedHash)
    {
        throw 'Unexpected MimeKitLite binary. Use the pinned net8.0 assembly installed by Install-EmlDependency.ps1.'
    }
    $loadedType = 'MimeKit.MimeMessage' -as [type]
    if ($null -ne $loadedType)
    {
        $assembly = $loadedType.Assembly
        if ($assembly.GetName().Name -ne 'MimeKitLite' -or
            [string]::IsNullOrWhiteSpace($assembly.Location) -or
            (Get-FileHash -LiteralPath $assembly.Location -Algorithm SHA256).Hash -ine $expectedHash)
        {
            throw 'A conflicting MimeKit assembly is already loaded. Start a clean PowerShell process for this pinned parser.'
        }
        return
    }
    [void][System.Reflection.Assembly]::LoadFrom($path)
}
