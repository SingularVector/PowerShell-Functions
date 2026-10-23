#Requires -Version 7.4

. (Join-Path $PSScriptRoot 'Private/Open-StandaloneRegistryKey.ps1')

function Export-Registry
{
    <#
    .SYNOPSIS
        Reports values from literal Windows Registry keys to objects, CSV or CLIXML.
    .DESCRIPTION
        Reads values on the supplied keys only, not descendant keys. Missing keys
        warn and continue. Empty keys yield no rows. The unnamed value has Name ''.
        Path is a stable native key-name string. XML preserves typed values; CSV is
        a text report and does not preserve array/binary types. Neither is a .reg
        backup. Existing export files are overwritten only after ShouldProcess.
    #>
    [CmdletBinding(DefaultParameterSetName = 'PrintOnly', SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('PSPath')]
        [ValidateNotNullOrEmpty()]
        [string[]]$KeyPath,

        [Parameter(ParameterSetName = 'Export', Mandatory)]
        [ValidateSet('xml', 'csv')]
        [string]$ExportFormat,

        [Parameter(ParameterSetName = 'Export', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExportPath,

        [switch]$NoBinaryData
    )
    begin { $rows = [System.Collections.Generic.List[object]]::new() }
    process
    {
        foreach ($path in $KeyPath)
        {
            $key = Open-StandaloneRegistryKey -Path $path
            if ($null -eq $key)
            {
                Write-Warning "Key $path does not exist."
                continue
            }
            try
            {
                foreach ($name in $key.GetValueNames())
                {
                    $kind = $key.GetValueKind($name)
                    if ($NoBinaryData -and $kind -eq [Microsoft.Win32.RegistryValueKind]::Binary) { continue }
                    $rows.Add([pscustomobject]@{
                        Path = [string]$key.Name
                        Name = [string]$name
                        Value = $key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                        Type = [string]$kind
                        Computername = [Environment]::MachineName
                    })
                }
            }
            finally { $key.Dispose() }
        }
    }
    end
    {
        if ($PSCmdlet.ParameterSetName -eq 'PrintOnly')
        {
            $rows.ToArray()
        }
        elseif ($rows.Count -eq 0)
        {
            Write-Warning 'No values matched; no export file was created or changed.'
        }
        elseif ($PSCmdlet.ShouldProcess($ExportPath, "Overwrite $ExportFormat registry report"))
        {
            if ($ExportFormat -eq 'csv')
            {
                $rows.ToArray() | Export-Csv -LiteralPath $ExportPath -NoTypeInformation -Force -ErrorAction Stop
            }
            else
            {
                $rows.ToArray() | Export-Clixml -LiteralPath $ExportPath -Force -ErrorAction Stop
            }
            Write-Verbose "Data written to $ExportPath"
        }
    }
}
