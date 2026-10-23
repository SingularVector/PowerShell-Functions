# PowerShell-Functions

A collection of reusable PowerShell functions developed to solve practical infrastructure and automation problems.

Many of these functions originated in day-to-day systems administration and later became part of larger PowerShell modules. They remain available here as standalone implementations so individual functions can be reviewed, reused, or adapted without importing an entire module.

The repository contains both historical Windows PowerShell utilities and newer code written for PowerShell 7+. Modernized functions are documented with their own compatibility requirements and, where appropriate, automated tests.

## Modernized functions

### New-LogEntry

A PowerShell 7+ logging implementation for production automation with:

- INFO, WARNING, and ERROR severity levels
- file and console output
- pipeline input and multiline-message handling
- in-memory buffering with retrieve, flush, and clear operations
- named mutex protection for concurrent file writers
- configurable lock timeout and abandoned-mutex handling
- opt-in secret redaction
- explicit pass-through output
- private helper functions and Pester 5 tests

See [`New-LogEntry/`](./New-LogEntry/) for documentation, source, tests, and change history.

### New-ApiRequest

The standalone OAuth-style request helper now follows the IT-ToolBox implementation. It requires PowerShell 7.4+, defaults to a form POST, supports dictionary headers and prevents client secrets from entering GET URLs. See [usage and migration notes](./docs/New-ApiRequest.md) and [tests](./Tests/New-ApiRequest.Tests.ps1). No module installation is required.

## Standalone functions

The repository also contains standalone utilities including:

- [`New-Timer`](./New-Timer.ps1) — creates and starts a `System.Diagnostics.Stopwatch` timer
- [`Get-ElapsedTime`](./Get-ElapsedTime.ps1) — returns elapsed-time information for a stopwatch
- [`Stop-Timer`](./Stop-Timer.ps1) — stops an existing stopwatch
- [`Get-TimerStatus`](./Get-TimerStatus.ps1) — returns the running state of a stopwatch
- [`New-ApiRequest`](./New-ApiRequest.ps1) — helper for API calls using OAuth2 authentication
- [`Test-IsGuid`](./Test-IsGuid.ps1) — validates GUID strings
- [`Convert-EmlFile`](./Convert-EmlFile.ps1) — converts `.eml` files into PowerShell objects
- [`New-StringConversion`](./New-StringConversion.ps1) — handles selected string/character conversion scenarios
- [`Test-IsRegistryKey`](./Test-IsRegistryKey.ps1) — validates registry keys for use by `Export-Registry`
- [`Export-Registry`](./Export-Registry.ps1) — exports registry data to CSV or XML
- [`Test-IsValidDn`](./Test-IsValidDn.ps1) — validates Active Directory distinguished-name input
- [`Get-UniqueUPN`](./Get-UniqueUPN.ps1) — generates or resolves unique UPN values
- [`Test-UpnExist`](./Test-UpnExist.ps1) — checks UPN existence

Some standalone functions predate the current PowerShell 7 modernization effort and may reflect the platform assumptions and coding practices of their original release. They are retained as part of the repository's history until each function is reviewed individually.

## Direction

Current maintenance focuses on:

- PowerShell 7+ for newly modernized code
- explicit public/private boundaries where a function requires supporting helpers
- Pester tests for behavior that is actively maintained
- clearer compatibility and platform documentation
- preserving useful history without rewriting working code purely for stylistic reasons

Functions may later be incorporated into dedicated modules when that provides a clearer public API.

## License

Unless a function states otherwise, repository content is released under the [MIT License](./LICENSE).
