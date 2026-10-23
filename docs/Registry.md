# Registry reporting corrections

PowerShell 7.4 on Windows is required for real registry operations. Test-IsRegistryKey and Export-Registry retain their root filenames and load Private/Open-StandaloneRegistryKey.ps1. Keep that helper when copying scripts. IT-ToolBox's Test-RegistryValue is not a substitute: it checks named values, while Test-IsRegistryKey checks key existence. IT-ToolBox is unchanged.

## Contract changes

- Keys and output filenames are literal paths. Wildcard metacharacters are not expanded.
- Missing keys return false from Test-IsRegistryKey. Export-Registry warns and continues; permission/provider/operational errors terminate.
- Registry handles are disposed after existence checks or value enumeration, including error paths.
- ExportFormat accepts csv and xml. The previously advertised reg option had no implementation and now fails parameter binding. For a restorable registry backup use an appropriate registry-native backup/export tool; this function creates reports.
- Output Path is a native registry-name string, not a live RegistryKey. Name is the actual value name; an existing unnamed/default value has Name ''. Empty keys yield no rows rather than a fabricated default value.
- NoBinaryData is available for object output and file output. Explicit NoBinaryData:$false preserves binary rows.
- XML uses CLIXML and preserves supported value types. CSV is a text report: arrays/binary data are not losslessly serialized by this format and cannot be treated as a backup. ExpandString values are read without expanding environment variables.
- No matched values means no export file is created or overwritten, even if filtering removed every row. Existing output files otherwise retain the historical overwrite behavior.
- WhatIf/Confirm guard file creation/overwrite, not the read-only registry queries. File errors terminate; success is reported only after the write succeeds.
- Reads values on the named keys only; it does not recursively enumerate descendants.

## Examples

```powershell
. ./Test-IsRegistryKey.ps1
. ./Export-Registry.ps1
Test-IsRegistryKey -KeyPath 'HKCU:\Software\Example'
Export-Registry -KeyPath 'HKCU:\Software\Example' -NoBinaryData
Export-Registry -KeyPath 'HKCU:\Software\Example' -ExportFormat xml -ExportPath './registry-report.xml' -WhatIf
```

The tests have offline key doubles for behavior/serialization/error handling, a non-Windows platform rejection check, and a Windows-only integration test that creates and removes a uniquely named temporary key under HKCU\Software. That test does not touch application keys and needs no HKLM writes. Run Invoke-Pester ./Tests/Registry.Tests.ps1 with Pester 5.7.1. The Windows CI result is required before production use; an offline passing run is not a Windows integration result.
