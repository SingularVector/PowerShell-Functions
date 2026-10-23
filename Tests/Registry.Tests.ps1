BeforeAll {
    . (Join-Path $PSScriptRoot '../Export-Registry.ps1')
    . (Join-Path $PSScriptRoot '../Test-IsRegistryKey.ps1')
    function New-FakeRegistryKey {
        param([switch]$Empty)
        $key=[pscustomobject]@{Name='HKEY_CURRENT_USER\Example';Disposed=$false;Empty=$Empty.IsPresent}
        $key | Add-Member ScriptMethod GetValueNames { if(-not $this.Empty){ @('Text','Bytes','') } }
        $key | Add-Member ScriptMethod GetValueKind {param($Name) if($Name-eq'Bytes'){[Microsoft.Win32.RegistryValueKind]::Binary}else{[Microsoft.Win32.RegistryValueKind]::String} }
        $key | Add-Member ScriptMethod GetValue {param($Name,$Default,$Options) if($Name-eq'Bytes'){return ,([byte[]]@(1,2))} elseif($Name-eq''){return 'default'}else{return '%TEMP%'} }
        $key | Add-Member ScriptMethod Dispose { $this.Disposed=$true }
        return $key
    }
}
Describe 'Registry reporting with offline key doubles' {
    BeforeEach {
        $script:key=New-FakeRegistryKey
        Mock Open-StandaloneRegistryKey {$script:key}
    }
    It 'returns stable path strings and preserves unexpanded data' {
        $rows=@(Export-Registry -KeyPath 'HKCU:\Example')
        $rows.Count | Should -Be 3
        $rows[0].Path | Should -BeExactly 'HKEY_CURRENT_USER\Example'
        $rows[0].Path | Should -BeOfType ([string])
        $rows[0].Value | Should -BeExactly '%TEMP%'
        $rows[2].Name | Should -BeExactly ''
        $script:key.Disposed | Should -BeTrue
    }
    It 'preserves binary rows with NoBinaryData false' {
        $rows=@(Export-Registry 'HKCU:\Example' -NoBinaryData:$false)
        @($rows | Where-Object Type -eq Binary).Count | Should -Be 1
    }
    It 'omits binary data only when enabled' {
        @(Export-Registry 'HKCU:\Example' -NoBinaryData).Count | Should -Be 2
    }
    It 'handles pipeline keys and literal metacharacters' {
        $null=@('HKCU:\A[1]','HKCU:\B*') | Export-Registry
        Should -Invoke Open-StandaloneRegistryKey -Times 1 -Exactly -ParameterFilter {$Path -ceq 'HKCU:\A[1]'}
        Should -Invoke Open-StandaloneRegistryKey -Times 1 -Exactly -ParameterFilter {$Path -ceq 'HKCU:\B*'}
    }
    It 'does not invent a default value for an empty key' {
        $script:key=New-FakeRegistryKey -Empty
        @(Export-Registry 'HKCU:\Empty').Count | Should -Be 0
        $script:key.Disposed | Should -BeTrue
    }
    It 'warns and returns no rows for a missing key' {
        Mock Open-StandaloneRegistryKey {$null}
        @(Export-Registry 'HKCU:\Missing' -WarningAction SilentlyContinue).Count | Should -Be 0
        Test-IsRegistryKey 'HKCU:\Missing' | Should -BeFalse
    }
    It 'propagates permission errors' {
        Mock Open-StandaloneRegistryKey {throw [UnauthorizedAccessException]::new('Access denied')}
        {Export-Registry 'HKCU:\Denied'} | Should -Throw '*Access denied*'
        {Test-IsRegistryKey 'HKCU:\Denied'} | Should -Throw '*Access denied*'
    }
    It 'closes the key even when reading fails' {
        $script:key | Add-Member ScriptMethod GetValueNames {throw 'Read failed'} -Force
        {Export-Registry 'HKCU:\Example'} | Should -Throw '*Read failed*'
        $script:key.Disposed | Should -BeTrue
    }
    It 'tests key existence and closes the handle' {
        Test-IsRegistryKey 'HKCU:\Example' | Should -BeTrue
        $script:key.Disposed | Should -BeTrue
    }
    It 'exports CSV and CLIXML with literal output paths' {
        $csv=Join-Path $TestDrive 'report[1].csv'
        Export-Registry 'HKCU:\Example' -ExportFormat csv -ExportPath $csv
        @(Import-Csv -LiteralPath $csv).Count | Should -Be 3
        $xml=Join-Path $TestDrive 'report[1].xml'
        Export-Registry 'HKCU:\Example' -ExportFormat xml -ExportPath $xml
        $rows=@(Import-Clixml -LiteralPath $xml)
        (@($rows | Where-Object Type -eq Binary)[0].Value -is [byte[]]) | Should -BeTrue
    }
    It 'honors WhatIf without changing a report' {
        $path=Join-Path $TestDrive 'keep.csv';Set-Content $path 'keep'
        Export-Registry 'HKCU:\Example' -ExportFormat csv -ExportPath $path -WhatIf
        (Get-Content $path) | Should -BeExactly 'keep'
    }
    It 'does not truncate existing reports when no values match' {
        $script:key=New-FakeRegistryKey -Empty
        $path=Join-Path $TestDrive 'keep.csv';Set-Content $path 'keep'
        Export-Registry 'HKCU:\Empty' -ExportFormat csv -ExportPath $path -WarningAction SilentlyContinue
        (Get-Content $path) | Should -BeExactly 'keep'
    }
    It 'rejects unsupported reg exports at binding' {
        {Export-Registry 'HKCU:\Example' -ExportFormat reg -ExportPath (Join-Path $TestDrive 'no.reg')} | Should -Throw
        Should -Invoke Open-StandaloneRegistryKey -Times 0 -Exactly
    }
    It 'propagates filesystem errors' {
        {Export-Registry 'HKCU:\Example' -ExportFormat csv -ExportPath $TestDrive} | Should -Throw
    }
}
Describe 'Real registry platform boundary' {
    It 'rejects non-Windows registry calls' -Skip:$IsWindows {
        {Test-IsRegistryKey 'HKCU:\Software'} | Should -Throw '*Windows Registry provider*'
        {Export-Registry 'HKCU:\Software'} | Should -Throw '*Windows Registry provider*'
    }
    It 'uses literal HKCU keys and actual value types on Windows' -Skip:(-not $IsWindows) {
        $parent='HKCU:\Software\RegistryFunctionTests-'+[guid]::NewGuid().ToString('N')
        $path=$parent+'\Literal[1]'
        try {
            $null=New-Item -Path $parent -Force
            $key=Get-Item -LiteralPath $parent
            try {$child=$key.CreateSubKey('Literal[1]')}finally{$key.Dispose()}
            try {
                $child.SetValue('Bytes',[byte[]]@(1,2),[Microsoft.Win32.RegistryValueKind]::Binary)
                $child.SetValue('Text','%TEMP%',[Microsoft.Win32.RegistryValueKind]::ExpandString)
                $child.SetValue('', 'unnamed',[Microsoft.Win32.RegistryValueKind]::String)
            } finally {$child.Dispose()}
            Test-IsRegistryKey $path | Should -BeTrue
            $rows=@(Export-Registry $path -NoBinaryData:$false)
            $rows.Count | Should -Be 3
            ($rows | Where-Object Name -eq Text).Value | Should -BeExactly '%TEMP%'
            @(Export-Registry $path -NoBinaryData).Count | Should -Be 2
            Test-IsRegistryKey ($parent+'\Missing') | Should -BeFalse
            {Test-IsRegistryKey $TestDrive} | Should -Throw '*Registry provider*'
        } finally {
            if(Test-Path -LiteralPath $parent){Remove-Item -LiteralPath $parent -Recurse -Force}
        }
    }
}
