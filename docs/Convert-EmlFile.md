# Convert-EmlFile: cross-platform MIME parsing

## Install once

Requires PowerShell 7.4+ (.NET 8+) and MimeKitLite 4.18.1. No IT-ToolBox installation is required; that module is not modified. MimeKitLite is the upstream MimeKit parser without most cryptography features. The net8.0 asset has no NuGet dependencies.

From the repository, in PowerShell:

```powershell
./scripts/Install-EmlDependency.ps1
. ./Convert-EmlFile.ps1
$message = Convert-EmlFile -EmlFileName './message.eml'
$message.Subject
$message.To
$message.Attachments
```

Only the explicit installer uses the network. It downloads a pinned NuGet package over HTTPS, checks its SHA-256, and extracts the net8.0 assembly. The original package is retained with its upstream MIT licensing metadata. Files go under ignored .eml-dependencies/MimeKitLite/4.18.1/. Nothing is installed globally. WhatIf performs no writes/downloads. A new custom destination can be selected with Destination; pass its DLL to Convert-EmlFile through MimeKitPath.

Keep Private/Import-EmlMimeKit.ps1 with the root function. Both package and DLL hashes are pinned; different releases require an intentional dependency update, updated hashes and regression tests. A conflicting MimeKit assembly in the current process produces an error: restart PowerShell rather than trying to replace a loaded assembly. Package 4.18.1 identifies its assembly version as 4.18.0.0, so file checksums, not that version string, identify the dependency.

## Output schema

One detached PSCustomObject per input file, with type name StandaloneFunctions.EmlMessage:

| Property | Meaning |
|---|---|
| SourcePath | Absolute source filename |
| MessageId | Parsed Message-Id, without enclosing angle brackets |
| Subject | Decoded subject, or null if absent |
| Date | DateTimeOffset if a usable Date header is parsed; otherwise null |
| From, To, Cc, Bcc, ReplyTo | Arrays of Name/Address objects; mailbox groups are flattened and group labels omitted |
| TextBody, HtmlBody | MimeKit-selected decoded body strings, or null; not all alternative body parts |
| Headers | Ordered Field/Value records, retaining repeated headers; not a byte-preserving raw header copy |
| Attachments | Metadata for attachment-disposition entities and inline resources: FileName, MimeType, ContentId, IsInline, IsAttachedMessage |

Attachment metadata contains no raw parser objects, streams, decoded byte arrays or extracted files. Inline resources with Content-ID and no disposition are included when not TextPart entities. Attached message/rfc822 parts are identified as attached messages, not recursively normalized into additional output messages. Names are untrusted original metadata, not safe output filenames. No attachment extraction is provided.

No HTML is rendered or sanitized and remote resources are not fetched. No S/MIME/OpenPGP decryption or signature verification is performed. Bodies and metadata remain untrusted message content.

## Errors and limits

Literal input paths avoid wildcard expansion; strings, arrays and FileInfo inputs are supported. Missing files, directories, nonfilesystem inputs, zero-length files, files exceeding MaxFileSizeBytes, dependency mismatches and parser errors terminate the invocation. Earlier results in a multi-file invocation may already have been emitted when a later file fails.

MaxFileSizeBytes defaults to 25 MiB and can be set up to 1 GiB. The check is applied to the opened stream before parsing. It limits input bytes, not total allocations or CPU time; this is not a hostile-input sandbox. MimeKit is intentionally tolerant of imperfect email syntax. Headerless input is rejected, but successful parsing is not full RFC validation and not every malformed multipart message will fail.

The input stream and MimeMessage are disposed in finally; the result remains usable after source deletion. No persistent parsing mode is used.

## Migration from COM

The historical function returned a live CDO.Message and needed Windows ADODB/CDO COM objects. This implementation deliberately changes that contract:

- Use TextBody and HtmlBody instead of CDO.TextBody/HTMLBody assumptions (PowerShell casing is insensitive, but object shape is new).
- Recipient properties are arrays of records rather than COM address-list strings.
- Headers is an ordered record array, not the CDO.Fields collection.
- Attachments supplies metadata, not COM attachment objects or an extraction API.
- There is no Send method, DataSource, native MIME object or byte-preserving Save operation on the result.

Retain the old implementation on a separate legacy branch if a caller needs its CDO-specific behavior; do not silently mix both contracts. Update consumers and inspect representative real messages before deployment. IT-ToolBox has no equivalent exported function to synchronize here.

## Tests and CI

Tests parse actual synthetic MIME fixtures: encoded UTF-8 headers and base64 body, Latin-1 quoted-printable body, multipart text/HTML, inline resources, binary attachment metadata and attached messages. They also cover repeated headers, literal paths, detached results and file-handle release, empty/malformed/missing/oversized inputs and dependency checks. Network calls are mocked in installer failure/WhatIf tests; no real mailboxes are accessed. CI explicitly installs the pinned dependency before the root test suites on Windows/Linux/macOS. Existing root-suite workflows are updated to do the same so they do not fail for a missing parser dependency.

```powershell
Import-Module Pester -RequiredVersion 5.7.1
Invoke-Pester ./Tests -Output Detailed
```

References:
https://www.nuget.org/packages/MimeKitLite/4.18.1
https://github.com/jstedfast/MimeKit
https://mimekit.net/docs/html/T_MimeKit_MimeMessage.htm
