function Convert-EmlFile
{
<#
    .SYNOPSIS
        Function will parse an eml files.
    
    .DESCRIPTION
        Function will parse eml file and return a normalized object that can be used to extract infromation from the encoded file.
    
    .PARAMETER EmlFileName
        A string representing the eml file to parse.
    
    .EXAMPLE
        PS C:\> Convert-EmlFile -EmlFileName 'C:\Test\test.eml'
    
    .OUTPUTS
        System.Object
#>
    [CmdletBinding()]
    [OutputType([object])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $EmlFileName
    )
    
    # Instantiate new ADODB Stream object
    $adoStream = New-Object -ComObject 'ADODB.Stream'
    
    # Open stream
    $adoStream.Open()
    
    # Load file
    $adoStream.LoadFromFile($EmlFileName)
    
    # Instantiate new CDO Message Object
    $cdoMessageObject = New-Object -ComObject 'CDO.Message'
    
    # Open object and pass stream
    $cdoMessageObject.DataSource.OpenObject($adoStream, '_Stream')
    
    return $cdoMessageObject
}