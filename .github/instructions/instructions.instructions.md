---
applyTo: '**'
---

# Github copilot instructions for a robust powershell 7 servicenow module

You’re building a PowerShell 7 module that cleanly abstracts ServiceNow’s REST APIs with consistent patterns, minimal maintenance, and dynamic operation handling via a JSON map. The goal is a framework Copilot can extend predictably: one scaffolding, many operations.

---

## Design goals and architecture

- **Module purpose:** A PowerShell 7 module providing typed, logged, and resilient functions to interact with ServiceNow (Change Management and beyond), driven by a JSON operations map to construct URIs and HTTP requests consistently. Reference the ServiceNow API docs for endpoints, methods, and request/response conventions.
- **Core pillars:**
  - **Configuration-driven:** Operations defined in a JSON file; functions assemble URIs/headers/body dynamically.
  - **Uniform scaffolding:** Every function shares the same signature, validation, logging, error handling, retry, and pagination.
  - **Separation of concerns:** HTTP client abstraction, auth, mapping, and operation functions are decoupled.
  - **Testability:** Pure functions where possible; mockable HTTP layer; Pester tests for each operation.
  - **Extensibility:** Adding a new API operation requires only a JSON entry and (optionally) a thin wrapper.

---

## Project structure and naming

- **Folders:**
  - **Label:** Module root
    - **Description:** ServiceNow.PowerShell/
  - **Label:** Public functions
    - **Description:** src/Public/*.ps1 (thin wrappers per API area, e.g., Change, Incident)
  - **Label:** Private helpers
    - **Description:** src/Private/*.ps1 (HTTP, auth, logging, validation, pagination)
  - **Label:** Operation maps
    - **Description:** maps/servicenow.operations.json (all endpoints)
  - **Label:** Config
    - **Description:** config/module.settings.json (instance, auth mode, defaults)
  - **Label:** Tests
    - **Description:** tests/*.Tests.ps1 (Pester)
  - **Label:** Docs
    - **Description:** docs/*.md (usage, conventions)
- **Module file:** ServiceNow.PowerShell.psm1 imports all functions and loads the JSON map.
- **Naming conventions:**
  - **Label:** Cmdlets
    - **Description:** Use PowerShell-approved verbs, e.g., Get-ServiceNowChange, New-ServiceNowChange, Update-ServiceNowChange, Invoke-ServiceNowRequest (low-level).
  - **Label:** Wrappers vs core
    - **Description:** Public “business” functions call a single core `Invoke-ServiceNowOperation` with a named operation key.

---

## JSON operations map schema

Use a single JSON file to describe operations. Copilot should generate and maintain entries here.

```json
{
  "basePath": "/api/now",
  "operations": {
    "Change.Get": {
      "path": "/table/change_request",
      "method": "GET",
      "auth": "Bearer",
      "query": {
        "sysparm_query": "number={number}",
        "sysparm_fields": "number,sys_id,state,short_description"
      }
    },
    "Change.New": {
      "path": "/table/change_request",
      "method": "POST",
      "auth": "Bearer",
      "body": {
        "short_description": "{short_description}",
        "type": "{type}",
        "assignment_group": "{assignment_group}"
      }
    },
    "Change.Update": {
      "path": "/table/change_request/{sys_id}",
      "method": "PATCH",
      "auth": "Bearer",
      "body": {
        "state": "{state}",
        "work_notes": "{work_notes}"
      }
    },
    "Change.Approve": {
      "path": "/table/approvals/{sys_id}",
      "method": "POST",
      "auth": "Bearer",
      "body": {
        "state": "approved"
      }
    }
  }
}
```

- **Label:** Token substitution
  - **Description:** `{var}` placeholders are replaced from function parameters.
- **Label:** Defaults and overrides
  - **Description:** Allow module-level defaults and per-call overrides for fields like `sysparm_fields`, `sysparm_limit`, etc.
- **Label:** Versioning
  - **Description:** Support multiple maps (e.g., zurich.json) if ServiceNow versions diverge.

---

## Core function templates

#### Invoke-ServiceNowOperation (private core)

```powershell
function Invoke-ServiceNowOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationKey,
        [Parameter()]
        [hashtable]$Params,
        [Parameter()]
        [hashtable]$Options
    )
    # Options: TimeoutSec, RetryCount, RetryDelaySec, Pagination, ExpectStatus, Fields, Query
    # Load map
    $op = Get-OperationDefinition -Key $OperationKey
    $uri = Build-ServiceNowUri -Operation $op -Params $Params
    $headers = Get-ServiceNowHeaders -Operation $op -Options $Options
    $body = Build-ServiceNowBody -Operation $op -Params $Params

    Invoke-WithRetry -ActionName "ServiceNow $OperationKey" -RetryCount ($Options.RetryCount ?? 3) -RetryDelaySec ($Options.RetryDelaySec ?? 2) {
        $resp = Invoke-RestMethod -Uri $uri -Method $op.method -Headers $headers -Body ($body ? (ConvertTo-Json $body) : $null) -ContentType 'application/json' -TimeoutSec ($Options.TimeoutSec ?? 60)
        Validate-Response -Response $resp -ExpectStatus ($Options.ExpectStatus ?? 200)
        Write-Log -Message "ServiceNow $OperationKey success" -Level Info -Context @{ Uri = $uri }
        return $resp
    }
}
```

#### Public wrapper pattern (thin, consistent)

```powershell
function Get-ServiceNowChange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Number,
        [string]$Fields,
        [int]$Limit = 100,
        [switch]$Raw
    )
    $params = @{ number = $Number }
    $options = @{ Fields = $Fields; Query = @{ sysparm_limit = $Limit } }
    $resp = Invoke-ServiceNowOperation -OperationKey 'Change.Get' -Params $params -Options $options
    if ($Raw) { return $resp } else { return $resp.result }
}
```

#### Helper functions (private)

```powershell
function Get-OperationDefinition {
    param([string]$Key)
    if (-not $script:ServiceNowOperations) { $script:ServiceNowOperations = Get-Content -Raw -Path "$PSScriptRoot/../maps/servicenow.operations.json" | ConvertFrom-Json }
    $script:ServiceNowOperations.operations[$Key]
}

function Build-ServiceNowUri {
    param([psobject]$Operation,[hashtable]$Params)
    $base = (Get-ModuleSetting -Key 'InstanceBaseUri') + ($script:ServiceNowOperations.basePath)
    $path = Replace-Tokens -Template $Operation.path -Params $Params
    $qs = Build-QueryString -Operation $Operation -Params $Params
    "$base$path$qs"
}

function Get-ServiceNowHeaders {
    param([psobject]$Operation,[hashtable]$Options)
    $token = Get-ServiceNowToken
    $h = @{ Authorization = "Bearer $token"; Accept = 'application/json' }
    if ($Options.Headers) { $Options.Headers.GetEnumerator() | % { $h[$_.Key] = $_.Value } }
    $h
}

function Build-ServiceNowBody {
    param([psobject]$Operation,[hashtable]$Params)
    if (-not $Operation.body) { return $null }
    ConvertTo-Hashtable (Replace-Tokens -Template $Operation.body -Params $Params)
}
```

---

## Resilience, auth, and cross-cutting concerns

- **Auth modes:**
  - **Label:** Bearer/OAuth2
    - **Description:** Default; store token securely (Windows DPAPI/SecretManagement). Automatic refresh via `Get-ServiceNowToken`.
  - **Label:** Basic auth
    - **Description:** Supported via headers when required; discourage for production.
- **Retries and transient handling:**
  - **Label:** Invoke-WithRetry
    - **Description:** Retry on 429/5xx with exponential backoff. Respect `Retry-After` if present.
- **Pagination:**
  - **Label:** Paged fetch
    - **Description:** Support `sysparm_limit` and `sysparm_offset`; provide `Get-ServiceNowPaged` helper to yield enumerables.
- **Validation:**
  - **Label:** Parameter validation
    - **Description:** Use `[ValidateSet()]` for enums (state, type), `[ValidatePattern()]` for IDs, and custom `Assert-Required` for body fields.
- **Error handling:**
  - **Label:** Uniform errors
    - **Description:** Normalize API errors into structured exceptions with `CategoryInfo`, `ErrorId`, and `Data` including `sys_id`, endpoint, correlation id.
- **Logging:**
  - **Label:** Structured logs
    - **Description:** `Write-Log` emits JSON lines (timestamp, level, action, uri, duration, status). Toggle via `$ServiceNow_LogLevel`.
- **Time and locale:**
  - **Label:** ISO 8601
    - **Description:** Format date/time fields consistently; convert to/from ServiceNow’s expected formats.

---

## Configuration and safety

- **Module settings:**
  - **Label:** Instance base URI
    - **Description:** e.g., https://yourinstance.service-now.com
  - **Label:** API path
    - **Description:** From JSON basePath; override per environment if needed.
  - **Label:** Defaults
    - **Description:** Global `sysparm_fields`, `sysparm_limit`, timeout, retry policy.
- **Secrets management:**
  - **Label:** Token storage
    - **Description:** Use Microsoft.PowerShell.SecretManagement or DPAPI via `Protect-Credential`.
- **Non-destructive mode:**
  - **Label:** Dry-run
    - **Description:** `-WhatIf` support on mutation functions (POST/PATCH/DELETE) with preview of payload and target URI.
- **Compliance:**
  - **Label:** Audit trail
    - **Description:** Record action, actor, endpoint, before/after states (where available) to a log file or Event Log.

---

## Testing, docs, and CI

- **Pester tests:**
  - **Label:** Map integrity
    - **Description:** Ensure all operations map entries have method/path placeholders valid.
  - **Label:** HTTP mocking
    - **Description:** Use `Mock Invoke-RestMethod` to simulate API responses and errors.
- **Examples:**
  - **Label:** Docs per function
    - **Description:** `.EXAMPLE` sections showing typical usage and error scenarios.
- **CI pipeline:**
  - **Label:** Lint and test
    - **Description:** PSScriptAnalyzer, Pester; publish on passing to an artifact feed.
- **Semantic versioning:**
  - **Label:** Version bumps
    - **Description:** Patch for fixes, minor for new ops, major for breaking changes.

---

## Copilot prompts and patterns

Give Copilot specific, consistent prompts so it generates the right scaffolding every time.

- **Label:** Operation entry prompt
  - **Description:** “Add a new ServiceNow operation to maps/servicenow.operations.json named ‘Change.Cancel’ with method POST, path /table/change_request/{sys_id}/cancel, body fields {reason} and {work_notes}, using Bearer auth.”
- **Label:** Public wrapper prompt
  - **Description:** “Create a public function New-ServiceNowChange that calls Invoke-ServiceNowOperation with OperationKey ‘Change.New’, parameters short_description, type, assignment_group; include `[CmdletBinding(SupportsShouldProcess)]`, validation, and return `$resp.result`.”
- **Label:** Retry/pagination prompt
  - **Description:** “Implement Invoke-WithRetry supporting 429 and 5xx with exponential backoff; honor Retry-After; make delays configurable via module settings.”
- **Label:** Logging prompt
  - **Description:** “Add Write-Log that outputs structured JSON with fields timestamp, level, action, uri, durationMs, statusCode; respect `$ServiceNow_LogLevel`.”
- **Label:** Tests prompt
  - **Description:** “Write a Pester test ensuring Get-ServiceNowChange returns an array when sysparm_limit > 1 and validates the constructed URI contains the expected query parameters.”

---

## Usage examples

```powershell
# Set instance and auth
Set-ModuleSetting -Key 'InstanceBaseUri' -Value 'https://yourinstance.service-now.com'
Set-ModuleSetting -Key 'AuthMode' -Value 'Bearer'
Set-Secret -Name 'ServiceNowToken' -Secret 'eyJ...'

# Get a change
Get-ServiceNowChange -Number 'CHG0030012' -Fields 'number,sys_id,state'

# Create a change (dry-run)
New-ServiceNowChange -Short_Description 'Patch Windows cluster' -Type 'normal' -Assignment_Group 'CAB' -WhatIf

# Update a change
Update-ServiceNowChange -Sys_Id 'abcd1234...' -State 'scheduled' -Work_Notes 'Approved by CAB'
```

---

## Final guidance

- **Start with the core:** Implement `Invoke-ServiceNowOperation`, token replacement, logging, retries, and pagination first.
- **Drive everything from JSON:** Keep wrappers thin; prefer adding map entries over writing new HTTP code.
- **Validate aggressively:** Fail fast on missing parameters or invalid enums.
- **Document decisions:** In docs/conventions.md, record patterns (naming, error model, defaults) so Copilot stays consistent.
- **Reference docs:** Align paths/methods with ServiceNow’s REST API for Change Management and related tables; keep your JSON map synced to the relevant release docs.

This blueprint gives Copilot the guardrails to generate a clean, maintainable, and extensible PowerShell 7 module that can scale across ServiceNow’s APIs with minimal churn.
