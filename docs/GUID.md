# Test-IsGuid: accepted formats

PowerShell 7.4+. Dot-source Test-IsGuid.ps1 as before. This is an independent standalone correction: IT-ToolBox does not export an equivalent function and is not changed.

Guid.TryParseExact accepts only N (32 hex digits), D (standard dashed), B (dashed inside matched braces), and P (dashed inside matched parentheses). Case is ignored. All-zero GUIDs are valid syntax. Surrounding whitespace, multiple lines, partial delimiter pairs, mixed hyphen layouts, undashed values inside braces and the X initializer representation are rejected. This intentionally removes false positives from the old optional-delimiter/multiline regex. It does not prove directory/object existence or require a specific UUID version.

Null/empty input returns false, including in pipelines. The function returns one Boolean per pipeline input. Existing ObjectGuid parameter name remains; positional invocation remains supported.

Run Invoke-Pester ./Tests/Guid.Tests.ps1 with Pester 5.7.1. CI runs the root test suites on Windows, Linux and macOS.
