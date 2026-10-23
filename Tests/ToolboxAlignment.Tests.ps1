BeforeAll {
    foreach ($name in @('New-StringConversion', 'Test-IsEmail', 'Test-IsValidDn', 'Get-ElapsedTime')) {
        . (Join-Path $PSScriptRoot ("../{0}.ps1" -f $name))
    }
}

Describe 'String conversion' {
    It 'returns one string without internal array indices' {
        $result = @(New-StringConversion -StringToConvert 'café')
        $result.Count | Should -Be 1
        $result[0] | Should -BeExactly 'cafe'
    }
    It 'preserves mapped uppercase and multi-character replacements' {
        New-StringConversion -StringToConvert 'CAFÉ Straße' | Should -BeExactly 'CAFE-Strasse'
        New-StringConversion -StringToConvert 'ÀÉÖ' | Should -BeExactly 'AEO'
    }
    It 'supports default, preserved, removed and custom spaces' {
        New-StringConversion -StringToConvert 'a b' | Should -BeExactly 'a-b'
        New-StringConversion -StringToConvert 'a b' -IgnoreSpaces | Should -BeExactly 'a b'
        New-StringConversion -StringToConvert 'a b' -RemoveSpaces | Should -BeExactly 'ab'
        New-StringConversion -StringToConvert 'a b' -ReplaceSpaces '_' | Should -BeExactly 'a_b'
        New-StringConversion -StringToConvert 'a b' -ReplaceSpaces '' | Should -BeExactly 'ab'
    }
    It 'does not mutate custom maps even if a space key exists' {
        $map = @{ 'é' = 'ee'; ' ' = 'original' }
        New-StringConversion -StringToConvert 'É é' -UnicodeHashTable $map -IgnoreSpaces | Should -BeExactly 'EE ee'
        $map.Count | Should -Be 2
        $map[' '] | Should -BeExactly 'original'
    }
    It 'uses the custom map instead of silently merging defaults' {
        New-StringConversion -StringToConvert 'éö' -UnicodeHashTable @{ 'é' = 'e' } | Should -BeExactly 'e?'
    }
    It 'normalizes decomposed accents and handles supplementary text elements once' {
        New-StringConversion -StringToConvert "cafe$([char]0x301)" | Should -BeExactly 'cafe'
        New-StringConversion -StringToConvert 'a🔐b' -UnknownCharacter '<unknown>' | Should -BeExactly 'a<unknown>b'
    }
    It 'preserves the historical permitted punctuation and special mappings' {
        New-StringConversion -StringToConvert 'A1!#$@.''^_~-' | Should -BeExactly 'A1!#$@.''^_~-'
        New-StringConversion -StringToConvert '&' | Should -BeExactly 'e'
        New-StringConversion -StringToConvert ':' | Should -BeExactly '?'
    }
    It 'rejects conflicting space policies and empty map keys' {
        { New-StringConversion -StringToConvert 'a b' -IgnoreSpaces -RemoveSpaces } | Should -Throw
        { New-StringConversion -StringToConvert 'a' -UnicodeHashTable @{ '' = 'x' } } | Should -Throw '*keys cannot be empty*'
    }
}

Describe 'Bare email-address validation' {
    It 'accepts a common bare address: <Value>' -ForEach @(
        @{ Value = 'person@example.com' }
        @{ Value = 'Person.Name+tag@EXAMPLE.COM' }
        @{ Value = "a!#$%&'*+-/=?^_``{|}~@example.com" }
        @{ Value = 'person@localhost' }
        @{ Value = 'person@bücher.example' }
        @{ Value = 'person@xn--bcher-kva.example' }
        @{ Value = 'person@sub-domain.example' }
    ) {
        Test-IsEmail -EmailAddress $Value | Should -BeTrue
    }

    It 'rejects a malformed or unsupported address: <Value>' -ForEach @(
        @{ Value = $null }; @{ Value = '' }; @{ Value = ' ' }
        @{ Value = 'not-an-email' }; @{ Value = 'person@' }; @{ Value = '@example.com' }
        @{ Value = ' person@example.com' }; @{ Value = 'person@example.com ' }
        @{ Value = "person@example.com`r`nBcc: other@example.com" }
        @{ Value = "per$([char]0)son@example.com" }
        @{ Value = 'Person <person@example.com>' }; @{ Value = '<person@example.com>' }
        @{ Value = 'person(comment)@example.com' }; @{ Value = 'person@example.com(comment)' }
        @{ Value = 'a@example.com,b@example.com' }; @{ Value = 'a@example.com;b@example.com' }
        @{ Value = 'a..b@example.com' }; @{ Value = '.person@example.com' }; @{ Value = 'person.@example.com' }
        @{ Value = '"person name"@example.com' }; @{ Value = 'pérson@example.com' }
        @{ Value = 'person@[127.0.0.1]' }; @{ Value = 'person@[IPv6:::1]' }
        @{ Value = 'person@-bad.example' }; @{ Value = 'person@bad-.example' }
        @{ Value = 'person@bad_domain.example' }; @{ Value = 'person@example..com' }
        @{ Value = 'person@example.com.' }; @{ Value = 'person@bad/example.com' }
    ) {
        Test-IsEmail -EmailAddress $Value | Should -BeFalse
    }

    It 'preserves the Email, Mail and Address parameter aliases' {
        Test-IsEmail -Email 'person@example.com' | Should -BeTrue
        Test-IsEmail -Mail 'person@example.com' | Should -BeTrue
        Test-IsEmail -Address 'person@example.com' | Should -BeTrue
    }

    It 'returns one boolean per pipeline record, including blank input' {
        $results = @('person@example.com', '', 'bad', 'person@localhost') | Test-IsEmail
        $results.Count | Should -Be 4
        ($results -join ',') | Should -Be 'True,False,False,True'
        foreach ($result in $results) { $result | Should -BeOfType ([bool]) }
    }

    It 'enforces local-part, DNS-label and complete-address length boundaries' {
        Test-IsEmail (('a' * 64) + '@example.com') | Should -BeTrue
        Test-IsEmail (('a' * 65) + '@example.com') | Should -BeFalse
        Test-IsEmail ('a@' + ('b' * 63) + '.example') | Should -BeTrue
        Test-IsEmail ('a@' + ('b' * 64) + '.example') | Should -BeFalse
        $domain = ('b' * 63) + '.' + ('c' * 63) + '.' + ('d' * 61)
        Test-IsEmail (('a' * 64) + '@' + $domain) | Should -BeTrue
        Test-IsEmail (('a' * 64) + '@' + $domain + 'e') | Should -BeFalse
        # IDN length is measured after conversion, not from the Unicode spelling.
        Test-IsEmail ('a@' + ('é' * 60) + '.example') | Should -BeFalse
    }
}


Describe 'Distinguished-name syntax policy' {
    It 'accepts supported syntax: <Value>' -ForEach @(
        @{ Value = 'CN=Person,OU=People,DC=example,DC=com' }
        @{ Value = 'cn=Person,dc=example,dc=technology' }
        @{ Value = 'CN=Last\, First,OU=People,DC=example' }
        @{ Value = 'CN=Last\2C First,DC=example' }
        @{ Value = 'CN=A\+B+UID=123,OU=People,DC=example' }
        @{ Value = 'CN=\ Leading\ ,DC=example' }
        @{ Value = 'CN=\#literal,DC=example' }
        @{ Value = 'CN=A=B,DC=example' }
        @{ Value = 'CN=Jörg,DC=example' }
        @{ Value = '2.5.4.3=#04024869,DC=example' }
        @{ Value = 'CN=Standalone' }
        @{ Value = 'CN=Back\\Slash,DC=example' }
    ) { Test-IsValidDn $Value | Should -BeTrue }
    It 'rejects malformed or unsupported syntax: <Value>' -ForEach @(
        @{ Value = $null }; @{ Value = '' }; @{ Value = ' ' }
        @{ Value = 'Person' }; @{ Value = 'CN=' }; @{ Value = 'CN=Person,' }
        @{ Value = ',CN=Person' }; @{ Value = 'CN=Person,,DC=example' }
        @{ Value = 'CN=Person+,DC=example' }; @{ Value = 'CN=Person,DC=' }
        @{ Value = ' CN=Person' }; @{ Value = 'CN= Person' }; @{ Value = 'CN=Person ' }
        @{ Value = 'CN=Person\' }; @{ Value = 'CN=A\z,DC=example' }
        @{ Value = 'CN=A\2Z,DC=example' }; @{ Value = 'CN="Last, First",DC=example' }
        @{ Value = 'CN=#odd' }; @{ Value = 'CN=#123' }; @{ Value = 'CN=A<B' }
        @{ Value = "CN=A`nB,DC=example" }; @{ Value = "CN=A$([char]0)B" }
    ) { Test-IsValidDn $Value | Should -BeFalse }
    It 'preserves aliases and produces one boolean per pipeline record' {
        Test-IsValidDN -DistinguishedName 'CN=Person' | Should -BeTrue
        Test-IsValidDn -DN 'CN=Person' | Should -BeTrue
        $result = @('CN=Person', '', 'bad') | Test-IsValidDn
        ($result -join ',') | Should -Be 'True,False,False'
    }
}


Describe 'Elapsed-time input validation' {
    It 'requires a non-null stopwatch in every parameter set' {
        $command = Get-Command Get-ElapsedTime -CommandType Function
        foreach ($set in $command.ParameterSets) {
            ($set.Parameters | Where-Object Name -eq ElapsedTime).IsMandatory | Should -BeTrue
        }
        { Get-ElapsedTime -ElapsedTime $null -Seconds } | Should -Throw
    }

    It 'returns the requested elapsed-time component: <Component>' -ForEach @(
        @{ Component = 'Days' }; @{ Component = 'Hours' }; @{ Component = 'Minutes' }
        @{ Component = 'Seconds' }; @{ Component = 'TotalDays' }; @{ Component = 'TotalHours' }
        @{ Component = 'TotalMinutes' }; @{ Component = 'TotalSeconds' }; @{ Component = 'TotalMilliseconds' }
    ) {
        $timer = [System.Diagnostics.Stopwatch]::new()
        $selector = @{ $Component = $true }
        Get-ElapsedTime -ElapsedTime $timer @selector | Should -Be $timer.Elapsed.$Component
    }
}

Describe 'Independent standalone loading' {
    It 'loads <Function> without IT-ToolBox or another function' -ForEach @(
        @{ Function = 'New-StringConversion'; Parameter = 'StringToConvert'; Argument = 'café'; Expected = 'cafe' }
        @{ Function = 'Test-IsEmail'; Parameter = 'EmailAddress'; Argument = 'person@example.com'; Expected = 'True' }
        @{ Function = 'Test-IsValidDn'; Parameter = 'ObjectDN'; Argument = 'CN=Person'; Expected = 'True' }
    ) {
        $path = (Resolve-Path (Join-Path $PSScriptRoot ("../{0}.ps1" -f $Function))).Path
        $result = & (Join-Path $PSHOME 'pwsh') -NoProfile -Command {
            param($Path, $Function, $Parameter, $Argument)
            . $Path
            $arguments = @{ $Parameter = $Argument }
            & $Function @arguments
        } -args $path, $Function, $Parameter, $Argument
        $LASTEXITCODE | Should -Be 0
        [string]$result | Should -BeExactly $Expected
    }
    It 'returns a TimeSpan when loaded independently' {
        $path = (Resolve-Path (Join-Path $PSScriptRoot '../Get-ElapsedTime.ps1')).Path
        $result = & (Join-Path $PSHOME 'pwsh') -NoProfile -Command {
            param($Path)
            . $Path
            $timer = [System.Diagnostics.Stopwatch]::new()
            (Get-ElapsedTime -ElapsedTime $timer).GetType().FullName
        } -args $path
        $LASTEXITCODE | Should -Be 0
        $result | Should -BeExactly 'System.TimeSpan'
    }
}
