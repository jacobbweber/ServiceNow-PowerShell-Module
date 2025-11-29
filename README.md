# ServiceNow PowerShell Module - Complete Build Summary

## Overview
A robust, configuration-driven PowerShell 7 module for ServiceNow Change Management API with pagination, retry logic, logging, and comprehensive tests.

## Module Structure

```
ServiceNow.PowerShell/
├── ServiceNow.PowerShell.psd1      # Module manifest
├── ServiceNow.PowerShell.psm1      # Module entry point
├── config/
│   └── module.settings.json        # Instance URI, auth, defaults
├── maps/
│   └── servicenow.operations.json  # API operations definition
├── src/
│   ├── Private/
│   │   ├── ModuleSettings.ps1      # Get/Set configuration
│   │   ├── Invoke-ServiceNowOperation.ps1  # Core HTTP client + helpers
│   │   └── Pagination.ps1          # Auto-pagination helper
│   └── Public/
│       └── Change.ps1              # Change Management wrappers
├── tests/
│   ├── ServiceNow.Operations.Tests.ps1   # 34 core tests
│   └── ServiceNow.Pagination.Tests.ps1   # 9 pagination tests
└── examples/
    ├── ChangeExample.ps1           # Basic usage examples
    └── PaginationDemo.ps1          # Pagination patterns
```

## Exported Functions

### GET Operations
- **Get-ServiceNowChange** `[-Number] <string> [-Fields <string>] [-Limit <int>] [-Paged] [-MaxRecords <int>] [-Raw]`
  - Retrieve change(s) by number
  - Non-paged: Single request up to limit
  - Paged: Auto-iterate; fetch all or up to MaxRecords

### CREATE Operations
- **New-ServiceNowChange** `[-Short_Description] <string> [-Type {normal|emergency|standard}] [-Assignment_Group <string>] [-Raw] [-WhatIf]`
  - Create new change request
  - Supports `-WhatIf` for dry-run

### UPDATE Operations
- **Update-ServiceNowChange** `[-Sys_Id] <string> [-State <string>] [-Work_Notes <string>] [-Raw] [-WhatIf]`
  - Update change state and work notes
  - Valid states: draft, submitted, pending, approved, rejected, scheduled, in_progress, implemented, closed, cancelled

### APPROVAL Operations
- **Approve-ServiceNowChange** `[-Sys_Id] <string> [-Comments <string>] [-Raw] [-WhatIf]`
  - Approve a pending change
- **Deny-ServiceNowChange** `[-Sys_Id] <string> [-Comments <string>] [-Raw] [-WhatIf]`
  - Deny a change request
- **Invoke-ServiceNowChangeCancel** `[-Sys_Id] <string> [-Reason <string>] [-Raw] [-WhatIf]`
  - Cancel an active change

## Operations Map

| Operation | Method | Path | Purpose |
|-----------|--------|------|---------|
| Change.Get | GET | /table/change_request | Retrieve change(s) |
| Change.New | POST | /table/change_request | Create new change |
| Change.Update | PATCH | /table/change_request/{sys_id} | Update change |
| Change.Approve | POST | /table/change_request/{sys_id}/approve | Approve change |
| Change.Deny | POST | /table/change_request/{sys_id}/deny | Deny change |
| Change.Cancel | POST | /table/change_request/{sys_id}/cancel | Cancel change |

## Key Features

### Configuration-Driven
- Single JSON map defines all API operations
- Token substitution: `{variable}` replaced from function params
- Defaults: sysparm_limit, timeout, retry policy

### Resilience
- `Invoke-WithRetry`: Exponential backoff on 5xx/429 errors
- Configurable retry count and delays
- Graceful error handling with structured messages

### Pagination
- **Get-ServiceNowPaged** (private helper)
- Automatic batch fetching via `sysparm_offset` and `sysparm_limit`
- `-Paged` switch: Auto-iterate through all results
- `-MaxRecords`: Cap total retrieval
- Pipeline-friendly: Yields results as they arrive

### Authentication
- Preferred: store token securely in PowerShell SecretManagement vault (recommended).

  Example (using `Microsoft.PowerShell.SecretManagement` and `Microsoft.PowerShell.SecretStore`):

  ```powershell
  # Install modules (if needed)
  Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore -Scope CurrentUser

  # Register a local vault (one-time)
  Register-SecretVault -Name MyVault -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault

  # Store token securely
  $secret = ConvertTo-SecureString 'eyJ....' -AsPlainText -Force
  Set-Secret -Name 'ServiceNowToken' -Secret $secret

  # Or use the module helper
  Set-ServiceNowToken -Token 'eyJ...'
  ```

- Fallback: Bearer token via environment variable `SERVICE_NOW_TOKEN` or `Set-ModuleSetting -Key Token` (not secure).

### Testing
- **43 Pester tests** (all passing)
  - Operations map integrity (6 tests)
  - Config validation (4 tests)
  - Function signatures & exports (6 tests)
  - Parameter validation (5 tests)
  - Token handling (2 tests)
  - `-WhatIf` support (5 tests)
  - Pagination features (9 tests)

### ShouldProcess Support
- All mutation functions (New, Update, Approve, Deny, Cancel) support `-WhatIf`
- Safe for use in scripts and automation

## Usage Examples

### Non-Paged (Single Request)
```powershell
$change = Get-ServiceNowChange -Number 'CHG0000123' -Limit 100
```

### Paged (Auto-Iterate All)
```powershell
$allChanges = @(Get-ServiceNowChange -Number 'CHG%' -Paged -Limit 50)
```

### Paged with Limit
```powershell
$someChanges = @(Get-ServiceNowChange -Number 'CHG%' -Paged -Limit 100 -MaxRecords 500)
```

### Stream Processing
```powershell
Get-ServiceNowChange -Number 'CHG%' -Paged -Limit 100 | ForEach-Object {
    Write-Host "Processing: $($_.number) - $($_.short_description)"
}
```

### Create with Dry-Run
```powershell
New-ServiceNowChange -Short_Description 'Deploy app' -Type normal -Assignment_Group 'CAB' -WhatIf
```

### Update Change
```powershell
Update-ServiceNowChange -Sys_Id 'abc123...' -State scheduled -Work_Notes 'Approved by team'
```

### Approve/Deny
```powershell
Approve-ServiceNowChange -Sys_Id 'abc123...' -Comments 'Looks good'
Deny-ServiceNowChange -Sys_Id 'abc123...' -Comments 'Conflicts with other change'
```

## Configuration

**config/module.settings.json**
```json
{
  "InstanceBaseUri": "https://yourinstance.service-now.com",
  "AuthMode": "Bearer",
  "Defaults": {
    "sysparm_limit": 100,
    "TimeoutSec": 60,
    "RetryCount": 3,
    "RetryDelaySec": 2
  }
}
```

**Set at Runtime**
```powershell
Set-ModuleSetting -Key 'InstanceBaseUri' -Value 'https://prod.service-now.com'
Set-ModuleSetting -Key 'Defaults.RetryCount' -Value 5
```

## Private Helpers (For Copilot Extension)

| Function | Purpose |
|----------|---------|
| `Get-ModuleSetting` | Read config key (dot-notation path support) |
| `Set-ModuleSetting` | Write config key (creates if missing) |
| `Get-OperationDefinition` | Load operation from map |
| `Replace-Tokens` | Substitute `{var}` in template |
| `Build-QueryString` | Construct query params from operation + params |
| `Build-ServiceNowUri` | Assemble full URI |
| `Get-ServiceNowToken` | Fetch token from env or config |
| `Get-ServiceNowHeaders` | Build HTTP headers (auth + accept) |
| `Build-ServiceNowBody` | Assemble request body |
| `Invoke-WithRetry` | Execute with exponential backoff |
| `Write-Log` | Emit structured JSON logs |
| `Invoke-ServiceNowOperation` | Core operation caller (load, build, call, retry) |
| `Get-ServiceNowPaged` | Auto-paginate through results |

## Next Steps (Roadmap)

1. **Incident Management** — Add Get/New/Update/Close for incidents
2. **Problem Management** — Add operations for problem tickets
3. **SecretManagement Integration** — Replace env var/config storage with secure vault
4. **Advanced Retry** — Honor `Retry-After` headers; circuit breaker pattern
5. **Logging Enhancement** — File/Event Log output option
6. **Module Publishing** — PowerShell Gallery, artifact feed
7. **CI/CD** — GitHub Actions for lint, test, publish
8. **Performance Metrics** — Built-in timing and cost tracking

## CI / GitHub Actions

A GitHub Actions workflow `/.github/workflows/ci.yml` is included to run linting and tests on push and PRs. It performs:

- PSScriptAnalyzer linting (errors cause job failure)
- Pester test execution (`Invoke-Pester -Path tests`)

There is also a scaffolded publish job that can publish to the PowerShell Gallery when the `PSGalleryApiKey` secret is configured in the repository settings.

Usage locally:
```powershell
# Run lint
Invoke-ScriptAnalyzer -Path . -Recurse

# Run tests
Invoke-Pester -Path tests
```

## Performance Metrics (Usage)

This module collects simple performance metrics for ServiceNow operations: total requests, total elapsed milliseconds, and per-operation counts and totals. Functions:

- `Get-ServiceNowMetrics` : Returns the metrics object
- `Reset-ServiceNowMetrics` : Clears collected metrics

Example:

```powershell
# Reset metrics
Reset-ServiceNowMetrics

# Run operations
Get-ServiceNowChange -Number 'CHG%'
Get-ServiceNowChange -Number 'CHG%' -Paged -Limit 50 | Out-Null

# Retrieve metrics
$metrics = Get-ServiceNowMetrics
Write-Host "Requests: $($metrics.Requests) TotalMs: $($metrics.TotalMs)"

# Per-operation detail
$metrics.Operations.GetEnumerator() | ForEach-Object { Write-Host "$($_.Key): Count=$($_.Value.Count) TotalMs=$($_.Value.TotalMs)" }
```


## Running Tests

```powershell
cd path/to/modules/snow
Invoke-Pester -Path tests -PassThru
# All 43 tests should pass
```

## Development Notes

- **Design Philosophy**: Configuration over code. Add operations to map before writing wrappers.
- **Function Pattern**: Public wrappers call `Invoke-ServiceNowOperation` with operation key.
- **Error Model**: Normalized exceptions with context (URI, sys_id, correlation ID).
- **Backward Compatibility**: Semver; patch for fixes, minor for new ops, major for breaking changes.

---
**Module Version**: 0.1.0  
**PowerShell**: 7.0+  
**Last Updated**: 2025-11-29
