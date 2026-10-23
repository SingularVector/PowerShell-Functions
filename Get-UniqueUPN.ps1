#Requires -Version 7.4

. (Join-Path $PSScriptRoot 'Test-UpnExist.ps1')
. (Join-Path $PSScriptRoot 'Private/Test-ITToolBoxDnsName.ps1')

function Get-UniqueUPN
{
    <#
    .SYNOPSIS
        Finds an available user principal name in the selected directory scope.
    .DESCRIPTION
        Accepts explicit name strings or ADUser, DirectoryEntry and SearchResult
        inputs. First and last name formatting are independent. Collisions append
        an integer to the complete local part; the search has a bounded attempt count.
        Availability is a preflight check, not a reservation or atomic uniqueness guarantee.
    .PARAMETER MaxAttempts
        Maximum candidates to check, including the initial unsuffixed name. Defaults to 1000.
    .PARAMETER AdServer
        Directory hostname, optionally with port. See Test-UPNExist for scope behaviour.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Strings')]
    [OutputType([string])]
    param (
        [Parameter(ParameterSetName = 'ADObject', Mandatory)]
        [ValidateNotNull()]
        [object]$ADObject,

        [Parameter(ParameterSetName = 'Strings', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FirstName,

        [Parameter(ParameterSetName = 'Strings', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LastName,

        [Parameter(ParameterSetName = 'Strings')]
        [string]$MiddleName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UPNSuffix,

        [ValidateSet('FullName', 'FirstLetter')]
        [string]$FirstNameFormat = 'FullName',

        [ValidateSet('FullName', 'FirstLetter')]
        [string]$LastNameFormat = 'FullName',

        [switch]$IncludeMiddleName,

        [Alias('Server')]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*(?::[0-9]{1,5})?$')]
        [string]$ADServer,

        [ValidatePattern('^[^\s@\p{Cc}]*$')]
        [AllowEmptyString()]
        [string]$Separator = '.',

        [ValidateSet('Forest', 'Domain')]
        [string]$SearchScope = 'Forest',

        [ValidateRange(1, 100000)]
        [int]$MaxAttempts = 1000
    )

    $givenName = $FirstName
    $surname = $LastName
    $middleNameValue = $MiddleName

    if ($PSCmdlet.ParameterSetName -eq 'ADObject')
    {
        if ($ADObject.PSObject.TypeNames -contains 'Microsoft.ActiveDirectory.Management.ADUser')
        {
            $givenName = [string]$ADObject.GivenName
            $surname = [string]$ADObject.Surname
            $middleNameValue = [string]$ADObject.MiddleName
        }
        elseif ($ADObject.PSObject.TypeNames -contains 'System.DirectoryServices.DirectoryEntry' -or
                $ADObject.PSObject.TypeNames -contains 'System.DirectoryServices.SearchResult')
        {
            $givenName = [string](@($ADObject.Properties['givenName'])[0])
            $surname = [string](@($ADObject.Properties['sn'])[0])
            $middleNameValue = [string](@($ADObject.Properties['middleName'])[0])
        }
        else
        {
            throw "Unsupported AD object type: $($ADObject.GetType().FullName)"
        }
    }

    foreach ($name in @($givenName, $surname))
    {
        if ([string]::IsNullOrWhiteSpace($name) -or $name.Trim() -match '[\s@\p{Cc}]')
        {
            throw 'First and last names must contain nonblank components without embedded whitespace, controls or @. Normalize compound names before calling.'
        }
    }
    if (-not (Test-ITToolBoxDnsName -Name $UPNSuffix))
    {
        throw 'UPNSuffix must be a DNS/IDN name without whitespace or a trailing root dot.'
    }

    $first = $givenName.Trim()
    $last = $surname.Trim()
    if ($FirstNameFormat -eq 'FirstLetter')
    {
        $first = [System.Globalization.StringInfo]::GetNextTextElement($first)
    }
    if ($LastNameFormat -eq 'FirstLetter')
    {
        $last = [System.Globalization.StringInfo]::GetNextTextElement($last)
    }
    $parts = [System.Collections.Generic.List[string]]::new()
    $parts.Add($first)
    if ($IncludeMiddleName -and -not [string]::IsNullOrWhiteSpace($middleNameValue))
    {
        $middle = $middleNameValue.Trim()
        if ($middle -match '[\s@\p{Cc}]')
        {
            throw 'Middle name must not contain embedded whitespace, controls or @.'
        }
        $parts.Add($middle)
    }
    $parts.Add($last)
    $localPart = ($parts -join $Separator).ToLowerInvariant()
    $suffix = $UPNSuffix.ToLowerInvariant()
    $lookup = @{ SearchScope = $SearchScope; ErrorAction = 'Stop' }
    if ($PSBoundParameters.ContainsKey('ADServer'))
    {
        $lookup.AdServer = $ADServer
    }

    for ($attempt = 0; $attempt -lt $MaxAttempts; $attempt++)
    {
        $counter = if ($attempt -eq 0) { '' } else { [string]$attempt }
        $candidate = '{0}{1}@{2}' -f $localPart, $counter, $suffix
        if (-not (Test-UPNExist -UPN $candidate @lookup))
        {
            return $candidate
        }
    }
    throw "No available UPN found after $MaxAttempts candidates."
}
