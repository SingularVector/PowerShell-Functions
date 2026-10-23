#Requires -Version 7.1

$script:NewLogEntryRoot = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($script:NewLogEntryRoot))
{
    $script:NewLogEntryRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
}

$script:NewLogEntrySourceFiles = @(
    'Private/Initialize-NewLogEntryState.ps1'
    'Private/Resolve-NewLogEntryPath.ps1'
    'Private/Get-NewLogEntryMutexName.ps1'
    'Private/ConvertTo-NewLogEntryRedactedMessage.ps1'
    'Private/Format-NewLogEntry.ps1'
    'Private/Write-NewLogEntryLines.ps1'
    'Private/Write-NewLogEntryConsole.ps1'
    'Private/Add-NewLogEntryBuffer.ps1'
    'Private/Get-NewLogEntryBuffer.ps1'
    'Private/Clear-NewLogEntryBuffer.ps1'
    'Public/New-LogEntry.ps1'
)

foreach ($sourceFile in $script:NewLogEntrySourceFiles)
{
    . (Join-Path -Path $script:NewLogEntryRoot -ChildPath $sourceFile)
}

if ($ExecutionContext.SessionState.Module)
{
    Export-ModuleMember -Function New-LogEntry
}
