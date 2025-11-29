# Example usage of the ServiceNow module - Change Management

Import-Module -Force (Join-Path $PSScriptRoot '..')

# Configure instance and token (for example only). Prefer secret management in real usage.
Set-ModuleSetting -Key 'InstanceBaseUri' -Value 'https://yourinstance.service-now.com'
# Option 1: export env var SERVICE_NOW_TOKEN
# $env:SERVICE_NOW_TOKEN = 'eyJ...'

# Example: Get change by number
try {
    Write-Host '=== GET Change ===' -ForegroundColor Cyan
    $change = Get-ServiceNowChange -Number 'CHG0000123' -Limit 1
    if ($change) { $change | Format-List }
} catch {
    Write-Error "Get failed: $_"
}

# Example: Create a change (will call ShouldProcess, use -WhatIf to preview)
try {
    Write-Host '=== CREATE Change ===' -ForegroundColor Cyan
    New-ServiceNowChange -Short_Description 'Example change created by script' -Type normal -Assignment_Group 'CAB' -WhatIf
} catch {
    Write-Error "Create failed: $_"
}

# Example: Update a change (set state and add work notes)
try {
    Write-Host '=== UPDATE Change ===' -ForegroundColor Cyan
    Update-ServiceNowChange -Sys_Id 'exampleSysId123' -State scheduled -Work_Notes 'Updated via script' -WhatIf
} catch {
    Write-Error "Update failed: $_"
}

# Example: Approve a change
try {
    Write-Host '=== APPROVE Change ===' -ForegroundColor Cyan
    Approve-ServiceNowChange -Sys_Id 'exampleSysId123' -Comments 'Approved by automation' -WhatIf
} catch {
    Write-Error "Approve failed: $_"
}

# Example: Deny a change
try {
    Write-Host '=== DENY Change ===' -ForegroundColor Cyan
    Deny-ServiceNowChange -Sys_Id 'exampleSysId123' -Comments 'Denied due to conflict' -WhatIf
} catch {
    Write-Error "Deny failed: $_"
}

# Example: Cancel a change
try {
    Write-Host '=== CANCEL Change ===' -ForegroundColor Cyan
    Invoke-ServiceNowChangeCancel -Sys_Id 'exampleSysId123' -Reason 'No longer needed' -WhatIf
} catch {
    Write-Error "Cancel failed: $_"
}

Write-Host '=== Examples Complete ===' -ForegroundColor Green

# ============================================================================
# Pagination Examples (Requires valid token and instance)
# ============================================================================
Write-Host ''
Write-Host '=== PAGINATION Examples ===' -ForegroundColor Magenta
Write-Host 'Uncomment and set $env:SERVICE_NOW_TOKEN to try these' -ForegroundColor Gray

<#
# Example: Get first 100 changes (non-paged, default limit)
$changes = Get-ServiceNowChange -Number 'CHG%' -Limit 100
Write-Host "Fetched $($changes.Count) changes"

# Example: Retrieve all changes in batches of 50
$allChanges = @(Get-ServiceNowChange -Number 'CHG%' -Paged -Limit 50)
Write-Host "Total changes: $($allChanges.Count)"

# Example: Get first 500 changes (stop after 500, even if more exist)
$someChanges = @(Get-ServiceNowChange -Number 'CHG%' -Paged -Limit 100 -MaxRecords 500)
Write-Host "Fetched up to 500: $($someChanges.Count)"

# Example: Process changes as they stream in (memory efficient)
Get-ServiceNowChange -Number 'CHG%' -Paged -Limit 100 | ForEach-Object {
    Write-Host "Processing: $($_.number) - $($_.short_description)"
}
#>

