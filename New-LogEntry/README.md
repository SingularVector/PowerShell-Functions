# New-LogEntry

`New-LogEntry` is a PowerShell 7.1+ logging function designed for production automation and troubleshooting. It writes timestamped log entries to files and the console, supports in-memory buffering, handles concurrent writers safely, accepts pipeline input, and can redact common secrets before log data leaves the process.

The function began as a small logging helper and has since been rewritten around a clearer public API, private helper functions, cross-platform file handling, and automated Pester tests.

## Requirements

- PowerShell 7.1 or later
- Pester 5 or later to run the test suite

The current implementation targets PowerShell 7.1+ on Windows, Linux, and macOS. Windows PowerShell 5.1 and earlier versions are not a compatibility target for this release.

## Repository layout

```text
New-LogEntry/
├── New-LogEntry.ps1
├── Public/
│   └── New-LogEntry.ps1
├── Private/
│   ├── Add-NewLogEntryBuffer.ps1
│   ├── Clear-NewLogEntryBuffer.ps1
│   ├── ConvertTo-NewLogEntryRedactedMessage.ps1
│   ├── Flush-NewLogEntryBuffer.ps1
│   ├── Format-NewLogEntry.ps1
│   ├── Get-NewLogEntryBuffer.ps1
│   ├── Get-NewLogEntryMutexName.ps1
│   ├── Initialize-NewLogEntryState.ps1
│   ├── Resolve-NewLogEntryPath.ps1
│   ├── Write-NewLogEntryConsole.ps1
│   └── Write-NewLogEntryLines.ps1
├── Tests/
│   └── New-LogEntry.Tests.ps1
├── CHANGELOG.md
└── LICENSE
```

`New-LogEntry.ps1` at the project root is the loader. It imports the private helper functions first and then exposes the public `New-LogEntry` function.

## Quick start

Dot-source the loader:

```powershell
. ./New-LogEntry.ps1
```

Write a standard informational entry:

```powershell
New-LogEntry -LogMessage 'Application started' -LogFilePath './application.log'
```

Write warning and error entries:

```powershell
New-LogEntry -LogMessage 'Configuration value missing' -Level WARNING -LogFilePath './application.log'
New-LogEntry -LogMessage 'Operation failed' -Level ERROR -LogFilePath './application.log'
```

`INFO` is the default level.

## Output behavior

By default, entries are written to both the configured log file and the console.

Use `-NoConsole` when running unattended automation:

```powershell
New-LogEntry -LogMessage 'Background task started' -LogFilePath './task.log' -NoConsole
```

Normal informational console output uses `Write-Host` so log messages do not unexpectedly pollute the PowerShell success pipeline.

When caller code needs the formatted entry as output, use `-PassThru`:

```powershell
$entry = New-LogEntry `
    -LogMessage 'Return this line' `
    -LogFilePath './application.log' `
    -NoConsole `
    -PassThru
```

## Pipeline input

`New-LogEntry` accepts messages from the pipeline:

```powershell
'one', 'two', 'three' | New-LogEntry -LogFilePath './application.log'
```

Pipeline input is collected during processing and written in one operation at the end of the invocation, reducing lock acquisition and file-write overhead.

Multiline messages are split so each physical line receives its own timestamp and severity prefix:

```powershell
New-LogEntry -LogMessage "Line one`nLine two" -LogFilePath './application.log'
```

## In-memory buffering

Log entries can be buffered instead of immediately written:

```powershell
New-LogEntry -LogMessage 'Step one complete' -BufferOnly
New-LogEntry -LogMessage 'Step two complete' -BufferOnly
```

Inspect the current buffer:

```powershell
New-LogEntry -GetBuffer
```

Flush buffered entries to disk and clear the buffer after a successful write:

```powershell
New-LogEntry -FlushBuffer -LogFilePath './application.log' -NoConsole
```

Clear the buffer without writing it:

```powershell
New-LogEntry -ClearBuffer
```

Buffer snapshot, file write and removal are synchronized as one operation. Failed
writes retain entries for retry; only the written prefix is removed on success.
A partial filesystem write can leave content on disk, so retrying after an I/O
failure does not guarantee exactly-once delivery.

Without `-LogFilePath`, logs are created beside the calling script, or in the
current directory for interactive calls. Specify a path for a stable filename. Callers should interact with the buffer through the public parameters rather than accessing the backing state directly.

## Concurrent file writes

File writes are protected by a named system mutex derived from the resolved log-file path. This prevents concurrent PowerShell processes writing to the same log file from interleaving or dropping entries while allowing unrelated log files to proceed independently.

The default lock timeout is 30 seconds and can be changed with `-LockTimeoutSeconds`:

```powershell
New-LogEntry `
    -LogMessage 'Concurrent-safe write' `
    -LogFilePath './application.log' `
    -LockTimeoutSeconds 10
```

Abandoned mutexes are handled so a failed writer does not permanently block later writes.

## Secret redaction

Secret redaction is opt-in.

Use `-RedactSecrets` to remove common credential patterns before entries are buffered, written, displayed, or returned:

```powershell
New-LogEntry `
    -LogMessage 'Authorization: Bearer abc123 password=SuperSecret' `
    -LogFilePath './application.log' `
    -RedactSecrets
```

Custom regular expressions can be supplied with `-RedactPattern`:

```powershell
New-LogEntry `
    -LogMessage 'sessionId=abc123 visible=yes' `
    -LogFilePath './application.log' `
    -RedactPattern 'sessionId=\S+'
```

Use `-RedactionText` to change the replacement text:

```powershell
New-LogEntry `
    -LogMessage 'token=abc123' `
    -LogFilePath './application.log' `
    -RedactSecrets `
    -RedactionText '<secret>'
```

`-RedactionText` is literal text: dollar signs are not expanded as regex substitutions.

Redaction reduces accidental credential exposure in logs, but it should not be treated as a substitute for proper secret-management practices.

## Backward-compatible severity switches

The preferred severity interface is `-Level`, but the legacy switches remain available for existing callers:

```powershell
New-LogEntry -LogMessage 'Warning' -IsWarningMessage -LogFilePath './application.log'
New-LogEntry -LogMessage 'Failure' -IsErrorMessage -LogFilePath './application.log'
```

Combining multiple buffered severity switches is rejected. Individual switches remain supported.

Mixing `-Level` with a legacy severity switch is rejected rather than silently choosing one behavior.

## Tests

The project includes a Pester 5 test suite covering the current behavioral contract, including:

- informational, warning, and error logging
- legacy severity switches
- conflicting parameter combinations
- multiline messages
- pipeline batching
- buffering, flushing, and clearing
- pass-through output
- built-in and custom secret redaction, including literal replacement text
- default paths from calling scripts and interactive sessions
- buffer retention and retry after failed writes
- simultaneous direct and buffered writes from three processes

Install Pester if necessary:

```powershell
Install-Module Pester -Scope CurrentUser
```

Run the suite from the `New-LogEntry` directory:

```powershell
Invoke-Pester ./Tests
```

## History

The full development history is documented in [CHANGELOG.md](./CHANGELOG.md).

## License

Released under the [MIT License](./LICENSE).

## Continuous integration

The New-LogEntry workflow runs the Pester suite on Windows, Linux, and macOS using each GitHub-hosted runner's installed PowerShell. It also checks PowerShell syntax and performs a separate loader smoke test. Pester is pinned to version 5.7.1.

PowerShell 7.1 is the API minimum because the mutex helper uses .NET 5 APIs. CI tests the runner versions, not every historical PowerShell release.

### Logger path and lock boundaries

Explicit log destinations must use the FileSystem provider. Non-filesystem paths
such as `Env:NAME` are rejected before file operations. Interactive calls from a
non-filesystem location require an explicit filesystem log destination; a calling
script can still supply the default directory through its own filesystem path.
A rejected flush preserves the buffer.

On Windows and macOS, case-only path aliases share a mutex. On case-sensitive Mac
volumes, distinct case-only filenames may therefore serialize unnecessarily.
Locks remain path-based: symlink/hard-link aliases are not resolved to file identity.
Upgrade all writers together: older macOS implementations can use different lock
names for lowercase paths. Keep one consistent path spelling during mixed-version
operation.
