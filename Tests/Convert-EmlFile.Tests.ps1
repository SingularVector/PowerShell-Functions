BeforeAll {
    . (Join-Path $PSScriptRoot '../Convert-EmlFile.ps1')
    $fixtures = Join-Path $PSScriptRoot 'Fixtures/Eml'
}
Describe 'EML normalization with real MimeKitLite parsing' {
    It 'decodes headers, mailbox groups and text content' {
        $r=Convert-EmlFile (Join-Path $fixtures 'plain.eml')
        $r.Subject | Should -BeExactly 'café'
        $r.From.Count | Should -Be 1
        $r.From[0].Name | Should -BeExactly 'Jörg'
        $r.From[0].Address | Should -BeExactly 'sender@example.com'
        $r.To.Count | Should -Be 2
        $r.Cc.Count | Should -Be 1
        $r.Bcc.Count | Should -Be 0
        $r.ReplyTo[0].Address | Should -BeExactly 'replies@example.com'
        $r.TextBody.Trim() | Should -BeExactly 'café'
        $r.MessageId | Should -BeExactly 'plain@example.com'
        $r.Date | Should -BeOfType ([DateTimeOffset])
        $r.Date.Offset.TotalHours | Should -Be 2
    }
    It 'works under StrictMode with absent optional fields' {
        Set-StrictMode -Version Latest
        $r=Convert-EmlFile (Join-Path $fixtures 'plain.eml')
        $r.Attachments.Count | Should -Be 0
        $r.Subject | Should -BeExactly 'café'
    }
    It 'preserves repeated headers in sequence' {
        $r=Convert-EmlFile (Join-Path $fixtures 'plain.eml')
        $values=@($r.Headers | Where-Object Field -eq 'X-Trace' | ForEach-Object Value)
        $values.Count | Should -Be 2
        ($values -join ',') | Should -BeExactly 'first,second'
    }
    It 'returns empty arrays and missing-body/date nulls for a header-only message' {
        $r=Convert-EmlFile (Join-Path $fixtures 'header-only.eml')
        $r.From.Count | Should -Be 0
        $r.Attachments.Count | Should -Be 0
        $r.Date | Should -BeNullOrEmpty
        $r.TextBody | Should -BeNullOrEmpty
        $r.HtmlBody | Should -BeNullOrEmpty
    }
    It 'decodes an older charset and quoted-printable body' {
        (Convert-EmlFile (Join-Path $fixtures 'latin1.eml')).TextBody.Trim() | Should -BeExactly 'café'
    }
    It 'handles multipart bodies, inline metadata and an attached message' {
        $r=Convert-EmlFile (Join-Path $fixtures 'multipart.eml')
        $r.TextBody | Should -Match 'Plain body'
        $r.HtmlBody | Should -Match '<p>HTML body</p>'
        $r.Attachments.Count | Should -Be 3
        ($r.Attachments | Where-Object FileName -eq '../danger.txt').MimeType | Should -BeExactly 'application/octet-stream'
        ($r.Attachments | Where-Object IsInline).ContentId | Should -BeExactly 'image-one'
        ($r.Attachments | Where-Object IsAttachedMessage).FileName | Should -BeExactly 'forwarded.eml'
    }
    It 'includes inline Content-ID parts without a disposition header' {
        $path=Join-Path $TestDrive 'cid.eml'
        $text=[System.IO.File]::ReadAllText((Join-Path $fixtures 'multipart.eml'))
        $text=$text -replace '(?m)^Content-Disposition: inline; filename="image.png"\r?\n', ''
        [System.IO.File]::WriteAllText($path,$text)
        $r=Convert-EmlFile $path
        $inline=@($r.Attachments | Where-Object IsInline)
        $inline.Count | Should -Be 1
        $inline[0].ContentId | Should -BeExactly 'image-one'
        $inline[0].FileName | Should -BeNullOrEmpty
    }
    It 'does not extract attachments or render/fetch HTML' {
        Mock Invoke-WebRequest {throw 'Parsing must not make network calls'}
        $sandbox=New-Item -ItemType Directory -Path (Join-Path $TestDrive 'no-extraction')
        Push-Location $sandbox.FullName
        try {
            $null=Convert-EmlFile (Join-Path $fixtures 'multipart.eml')
            @(Get-ChildItem -Force $sandbox.FullName).Count | Should -Be 0
            Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        } finally {Pop-Location}
    }
    It 'returns detached data that survives source deletion and serializes' {
        $path=Join-Path $TestDrive 'copy.eml'
        Copy-Item (Join-Path $fixtures 'multipart.eml') $path
        $r=Convert-EmlFile $path
        # FileShare.None would fail on Windows if the source stream was left open.
        $stream=[System.IO.File]::Open($path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
        $stream.Dispose()
        Remove-Item $path
        $r.TextBody | Should -Match 'Plain body'
        $r.Attachments[0].GetType().Name | Should -BeExactly 'PSCustomObject'
        ($r | ConvertTo-Json -Depth 10) | Should -Match 'forwarded.eml'
    }
    It 'uses literal filenames and returns one message per pipeline record' {
        $path=Join-Path $TestDrive 'mail[1].eml'
        Copy-Item (Join-Path $fixtures 'plain.eml') -Destination $path
        $rows=@(@($path,(Join-Path $fixtures 'header-only.eml')) | Convert-EmlFile)
        $rows.Count | Should -Be 2
        $rows[0].SourcePath | Should -BeExactly $path
    }
    It 'supports FileInfo input through its FullName property' {
        $r=Get-Item (Join-Path $fixtures 'plain.eml') | Convert-EmlFile
        $r.Subject | Should -BeExactly 'café'
    }
    It 'rejects missing files, directories, zero-length and headerless input' {
        {Convert-EmlFile (Join-Path $TestDrive 'missing.eml')} | Should -Throw
        {Convert-EmlFile $TestDrive} | Should -Throw '*filesystem file*'
        $empty=Join-Path $TestDrive 'empty.eml';[System.IO.File]::WriteAllBytes($empty,[byte[]]@())
        {Convert-EmlFile $empty} | Should -Throw '*nonempty*'
        {Convert-EmlFile (Join-Path $fixtures 'invalid.eml')} | Should -Throw
    }
    It 'honors the input-size boundary' {
        $path=Join-Path $fixtures 'plain.eml';$size=(Get-Item $path).Length
        {Convert-EmlFile $path -MaxFileSizeBytes ($size-1)} | Should -Throw '*at most*'
        (Convert-EmlFile $path -MaxFileSizeBytes $size).Subject | Should -BeExactly 'café'
        {Convert-EmlFile $path -MaxFileSizeBytes 0} | Should -Throw
    }
    It 'reports missing or unexpected binaries without downloading them' {
        Mock Invoke-WebRequest {throw 'No implicit downloads'}
        {Convert-EmlFile (Join-Path $fixtures 'plain.eml') -MimeKitPath (Join-Path $TestDrive 'missing.dll')} | Should -Throw '*dependency not found*'
        $fake=Join-Path $TestDrive 'wrong.dll';Set-Content $fake 'not a DLL'
        {Convert-EmlFile (Join-Path $fixtures 'plain.eml') -MimeKitPath $fake} | Should -Throw '*Unexpected MimeKitLite binary*'
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    }
}
Describe 'Dependency installer behavior' {
    It 'supports WhatIf without downloading or creating directories' {
        Mock Invoke-WebRequest {throw 'No download expected'}
        $path=Join-Path $TestDrive 'not-installed'
        & (Join-Path $PSScriptRoot '../scripts/Install-EmlDependency.ps1') -Destination $path -WhatIf
        Test-Path $path | Should -BeFalse
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    }
    It 'rejects altered packages before installation' {
        Mock Invoke-WebRequest {Set-Content -LiteralPath $OutFile 'corrupt package'}
        $path=Join-Path $TestDrive 'bad-install'
        {& (Join-Path $PSScriptRoot '../scripts/Install-EmlDependency.ps1') -Destination $path} | Should -Throw '*checksum mismatch*'
        Test-Path $path | Should -BeFalse
    }
}
