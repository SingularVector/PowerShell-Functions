#Requires -Version 7.4

. (Join-Path $PSScriptRoot 'Private/Import-EmlMimeKit.ps1')
$script:EmlDefaultAssemblyPath = Join-Path $PSScriptRoot '.eml-dependencies/MimeKitLite/4.18.1/MimeKitLite.dll'

function Convert-EmlFile
{
    <#
    .SYNOPSIS
        Parses local MIME messages into detached PowerShell objects.
    .DESCRIPTION
        Uses a pinned MimeKitLite dependency installed explicitly, never downloaded
        during parsing. Returns decoded bodies, mailbox lists, repeated headers and
        attachment metadata. Does not extract attachments, render HTML, validate
        signatures, decrypt content or return live parser/COM objects.
        File and parser errors terminate. MaxFileSizeBytes bounds input size only.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string[]]$EmlFileName,

        [ValidateNotNullOrEmpty()]
        [string]$MimeKitPath = $script:EmlDefaultAssemblyPath,

        [ValidateRange(1, 1073741824)]
        [long]$MaxFileSizeBytes = 26214400
    )
    begin { Import-EmlMimeKit -AssemblyPath $MimeKitPath }
    process
    {
        foreach ($fileName in $EmlFileName)
        {
            $file = Get-Item -LiteralPath $fileName -ErrorAction Stop
            if ($file.PSProvider.Name -ne 'FileSystem' -or $file.PSIsContainer)
            {
                throw "EML input must be a filesystem file: $fileName"
            }
            $stream = $null
            $message = $null
            try
            {
                $stream = [System.IO.File]::Open($file.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
                if ($stream.Length -eq 0 -or $stream.Length -gt $MaxFileSizeBytes)
                {
                    throw [System.IO.InvalidDataException]::new("EML input must be nonempty and at most $MaxFileSizeBytes bytes: $($file.FullName)")
                }
                $message = [MimeKit.MimeMessage]::Load($stream, $false, [System.Threading.CancellationToken]::None)
                if ($message.Headers.Count -eq 0)
                {
                    throw [System.FormatException]::new('EML input contains no parsed message headers.')
                }
                $mailboxes = @{}
                foreach ($field in @('From', 'To', 'Cc', 'Bcc', 'ReplyTo'))
                {
                    $mailboxes[$field] = @($message.$field.Mailboxes | ForEach-Object {
                        [pscustomobject]@{ Name = [string]$_.Name; Address = [string]$_.Address }
                    })
                }
                $attachments = @(
                    foreach ($part in $message.BodyParts)
                    {
                        $isAttachment = $part.IsAttachment
                        $disposition = $part.ContentDisposition
                        $isInline = ($null -ne $disposition -and $disposition.Disposition -eq 'inline') -or
                            (-not $isAttachment -and -not [string]::IsNullOrEmpty($part.ContentId) -and $part -isnot [MimeKit.TextPart])
                        if (-not $isAttachment -and -not $isInline) { continue }
                        $attachmentName = if ($null -ne $disposition) { $disposition.FileName } else { $null }
                        if ([string]::IsNullOrEmpty($attachmentName)) { $attachmentName = $part.ContentType.Name }
                        [pscustomobject]@{
                            FileName = $attachmentName
                            MimeType = [string]$part.ContentType.MimeType
                            ContentId = $part.ContentId
                            IsInline = [bool]$isInline
                            IsAttachedMessage = [bool]($part -is [MimeKit.MessagePart])
                        }
                    }
                )
                $date = $null
                if ($message.Headers.Contains('Date') -and $message.Date -ne [DateTimeOffset]::MinValue)
                {
                    $date = $message.Date
                }
                [pscustomobject]@{
                    PSTypeName = 'StandaloneFunctions.EmlMessage'
                    SourcePath = $file.FullName
                    MessageId = $message.MessageId
                    Subject = $message.Subject
                    Date = $date
                    From = $mailboxes.From
                    To = $mailboxes.To
                    Cc = $mailboxes.Cc
                    Bcc = $mailboxes.Bcc
                    ReplyTo = $mailboxes.ReplyTo
                    TextBody = $message.TextBody
                    HtmlBody = $message.HtmlBody
                    Headers = @($message.Headers | ForEach-Object { [pscustomobject]@{ Field = [string]$_.Field; Value = [string]$_.Value } })
                    Attachments = $attachments
                }
            }
            finally
            {
                if ($null -ne $message) { $message.Dispose() }
                if ($null -ne $stream) { $stream.Dispose() }
            }
        }
    }
}
