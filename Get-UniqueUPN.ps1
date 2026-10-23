function Get-UniqueUPN
{
<#
    .SYNOPSIS
        Cmdlet will generate a forest wide unique UPN.
    
    .DESCRIPTION
        Cmdlet will generate a forest wide unique UPN according to generation rules
        defined by the user.
        
        Cmdlet accept different types of objects to generate the UPN to allow greater flexibility
        
        ADObject - For example and object from Get-AdUser cmdlet
        Strings - Representing First Name, Last Name etc.
        DirectoryService Objects - For example when using native .Net methods to retrieve the identity
    
    .PARAMETER ADObject
        An ADObject for example output of the Get-ADUser cmdlet
    
    .PARAMETER FirstName
        A string representing the First Name of the user
    
    .PARAMETER LastName
        A string representing the Last Name of the user
    
    .PARAMETER MiddleName
        A string representing the Middle Name of the user, parameter is optional.
    
    .PARAMETER UPNSuffix
        A string representing the UPN suffix to be used.
    
    .PARAMETER FirstNameFormat
        A string representing the format to be for the First Name part of the UPN.
    
    .PARAMETER LastNameFormat
        A string representing the format to be for the Last Name part of the UPN.
    
    .PARAMETER IncludeMiddleName
        When paramenter is specified user Middle Name, if present, will be included in the UPN generation process.
    
    .PARAMETER ADServer
        A string representing the name of the AD Domain Controller that will be used to query Active Directory.
    
        If no server is specified the closest Global Catalog will be automatically selected.
    
    .PARAMETER Separator
        A string representing the separator to be used between UPN parts, defaults to a '.'.
#>
    
    [CmdletBinding(DefaultParameterSetName = 'Strings')]
    param
    (
        [Parameter(ParameterSetName = 'ADObject',
                   Mandatory = $true)]
        [object]$ADObject,
        [Parameter(ParameterSetName = 'Strings',
                   Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FirstName,
        [Parameter(ParameterSetName = 'Strings',
                   Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LastName,
        [Parameter(ParameterSetName = 'Strings')]
        [ValidateNotNullOrEmpty()]
        [string]$MiddleName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$UPNSuffix,
        [ValidateSet('FullName', 'FirstLetter', IgnoreCase = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FirstNameFormat = 'Full',
        [ValidateSet('FullName', 'FirstLetter', IgnoreCase = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LastNameFormat = 'FullName',
        [switch]$IncludeMiddleName,
        [ValidateNotNullOrEmpty()]
        [string]$ADServer,
        [ValidateNotNullOrEmpty()]
        [string]$Separator = '.'
    )
    
    if ($PSCmdlet.ParameterSetName -eq 'ADObject')
    {
        switch ($ADObject.GetType().FullName)
        {
            'Microsoft.ActiveDirectory.Management.ADUser'
            {
                [string]$firstName = $ADObject.GivenName
                [string]$lastName = $ADObject.Surname
                [string]$middleName = $ADObject.MiddleName
                
                break
            }
            'System.DirectoryServices.DirectoryEntry'
            {
                [string]$firstName = $ADObject.Properties['givenName'][0]
                [string]$lastName = $ADObject.Properties['sn'][0]
                [string]$middleName = $ADObject.Properties['middleName'][0]
                
                break
            }
            'System.DirectoryServices.SearchResult'
            {
                [string]$firstName = $ADObject.Properties['givenName'][0]
                [string]$lastName = $ADObject.Properties['sn'][0]
                [string]$middleName = $ADObject.Properties['middleName'][0]
                
                break
            }
            default
            {
                throw "Unsupported AD object type: $($ADObject.GetType().FullName)"
            }
        }
    }
    else
    {
        [string]$firstName = $FirstName
        [string]$lastName = $LastName
        [string]$middleName = $MiddleName
    }
    
    # Format first name
    $firstName = switch ($FirstNameFormat)
    {
        'FullName'
        {
            $firstName
        }
        'FirstLetter'
        {
            $firstName.Substring(0, 1)
        }
    }
    
    # Format last name
    $LastName = switch ($FirstNameFormat)
    {
        'FullName'
        {
            $LastName
        }
        'FirstLetter'
        {
            $LastName.Substring(0, 1)
        }
    }
    
    # Use middle name
    [string]$middleNamePart = if ($IncludeMiddleName -and $MiddleName)
    {
        '{0}{1}' -f $Separator, $MiddleName
    }
    
    # Setup required attributes
    [string]$baseUPN = ('{0}{1}{2}{3}@{4}' -f $FirstName, $middleNamePart, $Separator, $LastName, $UPNSuffix).ToLower()
    [string]$uniqueUPN = $baseUPN
    [int]$counter = 1
    
    while (Test-UPNExist -UPN $uniqueUPN -Server $ADServer)
    {
        $uniqueUPN = '{0}{1}@{2}' -f ($baseUPN.Split('@')[0]), $counter, $UPNSuffix
        
        $counter++
    }
    
    return $uniqueUPN
}