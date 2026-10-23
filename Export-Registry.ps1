function Export-Registry
{
    <#
        .SYNOPSIS
            Export registry item properties.
        
        .DESCRIPTION
            Export item properties for a given registry key.
            
            By default results will be written to the pipeline unless the -ExportFormat parameter is used.
        
        .PARAMETER KeyPath
            A string representing the Key(s) to export in the PsDrive format IE: HKCU:\SOFTWARE\TestSoftware
        
        .PARAMETER ExportFormat
            A string representing the format to use for the export.
        
            Possible values are: 
        
                - CSV
                - XML
        
            PArameter is used in conjunction with the ExportPath paramter.
        
        .PARAMETER ExportPath
            A string representing the path where keys should be exported.
        
        .PARAMETER NoBinaryData
            When parameter is specified any binary data present in the registry key is removed.
        
        .EXAMPLE
            PS C:\> Export-RegistryNew -KeyPath 'HKCU:\SOFTWARE\TestSoftware'
        
        .NOTES
            Additional information about the function.
    #>
    
    [CmdletBinding(DefaultParameterSetName = 'PrintOnly')]
    param
    (
        [Parameter(ParameterSetName = 'PrintOnly',
                   Mandatory = $true,
                   ValueFromPipeline = $true,
                   ValueFromPipelineByPropertyName = $true,
                   Position = 0,
                   HelpMessage = 'Enter a registry path using the PSDrive format (IE: HKCU:\SOFTWARE\TestSoftware')]
        [Parameter(ParameterSetName = 'Export',
                   Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('PSPath')]
        [string[]]
        $KeyPath,
        [Parameter(ParameterSetName = 'Export',
                   Mandatory = $true)]
        [ValidateSet('xml', 'csv', 'reg', IgnoreCase = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ExportFormat,
        [Parameter(ParameterSetName = 'Export',
                   Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ExportPath,
        [Parameter(ParameterSetName = 'Export')]
        [switch]
        $NoBinaryData
    )
    
    begin
    {
        # Initialize results array        
        [System.Collections.ArrayList]$returnData = @()
    }
    
    process
    {
        # Go through all paths
        foreach ($path in $KeyPath)
        {
            if ((Test-IsRegistryKey -KeyPath $path) -eq $true)
            {
                Write-Verbose "Getting properties for key: $path"
                
                # Get registry item
                $paramGetItem = @{
                    Path        = $path
                    ErrorAction = 'Stop'
                }
                
                [Microsoft.Win32.RegistryKey]$regItem = Get-Item @paramGetItem
                
                # Get key properties
                [array]$regItemProperties = $regItem.'Property'
                
                if ($regItemProperties.Count -gt 0)
                {
                    # Enumerate properties
                    foreach ($property in $regItemProperties)
                    {
                        Write-Verbose "Exporting $property"
                        
                        # Append data to return array
                        [void]($returnData.Add([pscustomobject]@{
                                    'Path'  = $regItem
                                    'Name'  = $property
                                    'Value' = $regItem.GetValue($property, $null, 'DoNotExpandEnvironmentNames')
                                    'Type'  = $regItem.GetValueKind($property)
                                    'Computername' = $env:computername
                                }))
                    }
                }
                else
                {
                    # Return default object
                    [void]($returnData.Add([pscustomobject]@{
                                'Path'         = $regItem
                                'Name'         = '(Default)'
                                'Value'        = $null
                                'Type'         = 'String'
                                'Computername' = $env:computername
                            }))
                }
            }
            else
            {
                Write-Warning -Message "Key $path does not exist"
                
                continue
            }
        }
    }
    
    end
    {
        # Check we have results
        if ($null -ne $returnData)
        {
            switch ($PSCmdlet.ParameterSetName)
            {
                'Export'
                {
                    # Remove binary data
                    if ($PSBoundParameters.ContainsKey('NoBinaryData'))
                    {
                        Write-Verbose -Message 'Removing binary data from return values'
                        
                        # Remove binary data
                        $returnData = $returnData | Where-Object { $_.Type -ne 'Binary' }
                    }
                    
                    switch ($ExportFormat)
                    {
                        'csv'
                        {
                            # Export to CSV
                            $returnData | Export-Csv -Path $ExportPath -NoTypeInformation -Force
                        }
                        'xml'
                        {
                            # Export to XML and overwrite
                            $returnData | Export-Clixml -Path $ExportPath -Force
                        }
                    }
                    
                    Write-Verbose -Message "Data written to $ExportPath"
                }
                
                default
                {
                    Write-Verbose -Message 'No data will be exported'
                    
                    # Print on screen only
                    $returnData
                }
            }
        }
        else
        {
            Write-Warning -Message 'No found - No export will be created'
        }
    }
}