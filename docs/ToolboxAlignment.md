# Standalone alignment: conversion, validation and elapsed time

These four implementations are backported from IT-ToolBox master a73f0af. The public function bodies and required helpers are unchanged. Root scripts add PowerShell 7.4 requirements and explicit helper loading. No IT-ToolBox module installation is required.

## Loading

```powershell
. ./New-StringConversion.ps1
. ./Test-IsEmail.ps1
. ./Test-IsValidDn.ps1
. ./Get-ElapsedTime.ps1
```

Each file loads independently. Preserve the repository's Private/ directory when copying helper-dependent functions; copying the root file alone is no longer sufficient. Helper names retain the ITToolBox prefix to match the source implementation. Private/ is a maintenance convention: dot-sourcing makes those helper functions visible in the caller's scope, so this is not an enforced module-private boundary. Installing these scripts does not import or alter an existing IT-ToolBox module.

## Intentional contract changes

### New-StringConversion

Returns one string, without internal collection indices. Default spaces become hyphens; IgnoreSpaces, RemoveSpaces and ReplaceSpaces choose alternatives. An empty replacement is allowed. Custom maps replace the default map and are copied rather than modified. Input is normalized to Unicode Form C and processed as text elements, with invariant case handling. Unsupported text elements use UnknownCharacter. This is a specific character-conversion policy, not general transliteration or removal of non-Unicode characters. Helper: Get-ITToolBoxCharacterMap.ps1.

### Test-IsEmail

Returns a Boolean per input, including false for null/empty values. Existing Email/Mail/Address aliases remain. Accepts a practical bare-address subset: ASCII dot-atom local parts and DNS/IDN domains, including single-label domains. Rejects display-name wrappers, comments, quoted local parts, address literals and Unicode local parts. Syntax validation does not establish mailbox existence or deliverability. This narrows the historical MailAddress-only acceptance policy. Helper: Test-ITToolBoxDnsName.ps1.

### Test-IsValidDn

Returns a Boolean per input, preserving DN/DistinguishedName aliases. Supports attribute names/OIDs, escaped separators, hex escapes and multi-valued RDNs. Rejects empty values, unescaped edge spaces, controls, invalid escapes and legacy quoted values. Does not require CN/OU/DC or a DC suffix. It checks a documented practical syntax subset, not schema, existence, decoded UTF-8 validity or full RFC conformance. Helper: Test-ITToolBoxDnSyntax.ps1.

### Get-ElapsedTime

The non-null Stopwatch input is mandatory in every parameter set. Parameter name ElapsedTime and all existing selectors remain. Default output is TimeSpan. Seconds/Minutes/Hours return components; TotalSeconds/TotalMinutes/TotalHours return totals. The distinction is unchanged.

## Tests and source alignment

The standalone test suite selects the existing IT-ToolBox StringUtilities, EmailUrlValidation, AdHelpers and Module regression cases for these four functions. It adapts loading and command discovery only, plus independent-process loading checks. The standalone API suite from the prior batch remains unchanged. No live directory, mail or network calls are used. The added workflow runs both standalone suites on Windows, Linux and macOS with Pester 5.7.1 and each runner's installed PowerShell.

Future changes should be reconciled with IT-ToolBox public implementations and helpers rather than developed as independent fixes. The existing New-LogEntry workflow and implementation remain untouched.
