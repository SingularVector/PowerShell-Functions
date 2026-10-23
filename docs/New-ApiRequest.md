# New-ApiRequest

Requires PowerShell 7.4 or later. Dot-source `New-ApiRequest.ps1`; IT-ToolBox does not need to be installed.

This standalone function adopts IT-ToolBox’s Public/New-ApiRequest.ps1 from master a73f0af. Its implementation body is copied unchanged; the standalone file adds an explicit runtime requirement. The tests adapt Tests/ApiRequest.Tests.ps1 to an isolated standalone test module.

## Usage

```powershell
. ./New-ApiRequest.ps1
# Supply the actual secret through your application's secret handling.
New-ApiRequest -ApiKey 'client-id' -ApiSecret $secret -ApiUrl 'https://example.invalid/token'
```

This submits an OAuth-style client request and returns the endpoint response. It does not acquire a token and then call a second API, refresh tokens or retry failures.

## Changes from the historical standalone version

- POST with application/x-www-form-urlencoded is now the default, rather than GET.
- Headers must be an IDictionary, for example a hashtable. Content-Type belongs in ContentType, not Headers.
- ContentType accepts application/x-www-form-urlencoded or application/json for POST. JSON bodies are serialized explicitly.
- Optional parameters are processed independently; method, headers, content type and client secret can be passed together.
- GET is allowed only without ApiSecret, and cannot specify ContentType.
- ApiSecret and Authorization headers require HTTPS. Other custom headers must also be handled according to their sensitivity: these guards are not a general-purpose secret detector.
- URLs must be absolute HTTP(S) addresses without embedded user information.
- Automatic redirects are disabled. Operational HTTP failures terminate and are not retried.
- ConnectionTimeoutSeconds defaults to 30, accepts 1–300, and has TimeoutSec as an alias. This is a connection timeout, not an overall request deadline.

Update callers that depend on the old GET default, string headers, unrestricted content types or automatic redirects. Keep any future functional correction aligned with the module implementation and adapt its existing regression tests.

## Tests

Run `Invoke-Pester ./Tests/New-ApiRequest.Tests.ps1 -Output Detailed` with Pester 5.7.1. Tests mock all requests; they do not contact an identity provider. CI runs the same suite on Windows, Linux and macOS using each runner’s installed PowerShell, not every PowerShell release.
