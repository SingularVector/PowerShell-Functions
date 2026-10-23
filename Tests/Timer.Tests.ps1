BeforeAll {
    foreach ($name in 'New-Timer','Stop-Timer','Get-TimerStatus','Get-ElapsedTime') {
        . (Join-Path $PSScriptRoot "../$name.ps1")
    }
}
Describe 'Stopwatch lifecycle' {
    It 'starts, reports status, stops and preserves elapsed time' {
        $timer=New-Timer
        $timer | Should -BeOfType ([System.Diagnostics.Stopwatch])
        Get-TimerStatus $timer | Should -BeTrue
        [System.Threading.SpinWait]::SpinUntil([Func[bool]]{$timer.ElapsedTicks -gt 0},1000) | Should -BeTrue
        Stop-Timer $timer | Should -BeTrue
        Get-TimerStatus $timer | Should -BeFalse
        $ticks=$timer.ElapsedTicks
        $ticks | Should -BeGreaterThan 0
        Stop-Timer $timer | Should -BeTrue
        $timer.ElapsedTicks | Should -Be $ticks
        (Get-ElapsedTime -ElapsedTime $timer).Ticks | Should -Be $timer.Elapsed.Ticks
    }
    It 'does not start a stopwatch that was never started' {
        $timer=[System.Diagnostics.Stopwatch]::new()
        Stop-Timer $timer | Should -BeTrue
        Get-TimerStatus $timer | Should -BeFalse
        $timer.ElapsedTicks | Should -Be 0
    }
    It 'rejects null and incompatible inputs' {
        {Stop-Timer -Timer $null} | Should -Throw
        {Get-TimerStatus -Timer $null} | Should -Throw
        {Stop-Timer -Timer 'invalid'} | Should -Throw
        {Get-TimerStatus -Timer 'invalid'} | Should -Throw
    }
    It 'preserves caller error preferences' {
        $ErrorActionPreference='Continue'
        $timer=New-Timer
        Stop-Timer $timer | Should -BeTrue
        $ErrorActionPreference | Should -Be 'Continue'
        {Stop-Timer -Timer $null} | Should -Throw
        $ErrorActionPreference | Should -Be 'Continue'
    }
    It 'accepts verbose diagnostics and returns a boolean' {
        $timer=New-Timer
        $result=Stop-Timer $timer -Verbose
        $result | Should -BeOfType ([bool])
        Get-TimerStatus $timer -Verbose | Should -BeFalse
    }
}
