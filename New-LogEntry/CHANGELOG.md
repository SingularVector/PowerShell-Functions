# New-LogEntry - Change History

## Version 2.1.0

- Refactored message formatting, console output, file writes, and buffer handling to remove duplicated logic
- Added *-GetBuffer*, *-FlushBuffer*, and *-ClearBuffer* parameters so buffered log entries can be retrieved or written without relying on direct access to a scoped variable
- Replaced the single global mutex name with a per-log-file mutex name derived from the resolved log path
- Switched file writes to .NET append operations with UTF-8 without BOM for consistent PowerShell 7+ behavior on Windows, Linux, and macOS
- Added abandoned mutex handling so a previous failed writer does not permanently block later log writes
- Added *-LockTimeoutSeconds* to avoid waiting forever for a log file lock
- Added thread-safe buffer access for runspace scenarios
- Added *-Level* as the preferred severity API while retaining legacy severity switches
- Added *-PassThru* so callers can opt into receiving formatted log entries on the success output stream
- Split multiline messages so each physical log line receives its own timestamp and severity prefix
- Moved helper functions out of the main function body to avoid redefining them on every call
- Split public and private functions into separate files under *Public/* and *Private/* while keeping *New-LogEntry.ps1* as the loader
- Batched pipeline input so multiple piped messages are written or buffered with one operation instead of one lock/write cycle per message
- Added opt-in secret redaction with *-RedactSecrets*, *-RedactPattern*, and *-RedactionText*
- Added initial Pester test suite covering logging, buffering, pass-through output, multiline messages, pipeline input, and redaction
- General code style cleanup

## Version 2.0.4

- Fixed an issue causing cmdlet to hang when using **-BufferOnly** parameters
- Implemented explicit mutex release

## Version 2.0.3

- Moved comment based help in function body

## Version 2.0.2

- Removed the *-NoTimeStamp* parameter from function

## Version 2.0.1

- Fixed typo in header section
- Updated header section with missing examples
- Added missing comment based help

## Version 2.0.0

- Function now uses [Mutex objects](https://docs.microsoft.com/en-us/windows/win32/sync/mutex-objects) to avoid situations where function was called before lock on log file was released causing exceptions to be thrown and log lines to be missed
- Code rewritten from scratch optimized for execution time
- Implemented the *[Info]* tag by default prepended to all log messages when not using the *-IsError* or *-IsWarning* parameters
- Optimized function to write log messages to a buffer rather than a file stream
- Implemented *-BufferOnlyInfo*, *-BufferOnlyWarning* and *BufferOnlyError* to better handle redirection of messages to buffer rather than a file
- Log messages will now be printed to console by default unless the *-NoConsole* parameter is used to allow easier troubleshooting of runtime scripts
- Updated timestamp format to use **MM/dd/yyyy hh:mm:ss tt** format to clearly indicate AM/PM time of the log
- Fixed an issue causing function to throw an exception when log filename contained special characters like *[*

## Version 1.1.2

- Time stamp will now include year in the format MM-dd-yy

## Version 1.1.1

- Function now supports *ShouldProcess* directive
- Introduced support for passing log messages via PipeLine
- Implemented additional aliases
- Minor case style cleanup

## Version 1.1.0

- Removed unused code
- Updated Header section
- Splatted commands for better readability
- Implemented  **NoTimeStamp** parameter to suppress log timestamp
- Fixed an issue causing Write-Error not to be correctly called
- Various code optimizations

## Version 1.0.0

- Initial Release
