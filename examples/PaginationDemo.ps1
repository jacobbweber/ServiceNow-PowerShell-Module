# Pagination Demo - ServiceNow Module
# This script demonstrates how pagination works with the ServiceNow module.

Import-Module -Force (Join-Path $PSScriptRoot '..')

# SETUP: Set your instance and token before running
# Set-ModuleSetting -Key 'InstanceBaseUri' -Value 'https://yourinstance.service-now.com'
# $env:SERVICE_NOW_TOKEN = 'your-token-here'

# ============================================================================
# Demo 1: Non-Paged Retrieval (Single Request)
# ============================================================================
Write-Host '=== Demo 1: Non-Paged (Single Request) ===' -ForegroundColor Cyan
Write-Host 'Get first 100 changes matching number like "CHG%"' -ForegroundColor Gray

<#
$changes = Get-ServiceNowChange -Number 'CHG%' -Limit 100
Write-Host "Retrieved: $($changes.Count) changes" -ForegroundColor Green
$changes | Select-Object number, short_description | Format-Table -AutoSize
#>

Write-Host 'Expected: Returns array of up to 100 records (or fewer if fewer exist)' -ForegroundColor Yellow

# ============================================================================
# Demo 2: Paged Retrieval (All Records, Auto-Paginate)
# ============================================================================
Write-Host ''
Write-Host '=== Demo 2: Paged (All Records with Auto-Pagination) ===' -ForegroundColor Cyan
Write-Host 'Get ALL changes in batches of 50 (continues until no more)' -ForegroundColor Gray

<#
$allChanges = @(Get-ServiceNowChange -Number 'CHG%' -Paged -Limit 50)
Write-Host "Retrieved: $($allChanges.Count) total changes" -ForegroundColor Green
Write-Host "  (Each batch fetched 50 at a time from API)" -ForegroundColor Gray
#>

Write-Host 'Expected: Yields records as they arrive; scales to thousands' -ForegroundColor Yellow

# ============================================================================
# Demo 3: Paged with MaxRecords Limit
# ============================================================================
Write-Host ''
Write-Host '=== Demo 3: Paged with MaxRecords (Stop After 500) ===' -ForegroundColor Cyan
Write-Host 'Get up to 500 changes in batches of 100, then stop' -ForegroundColor Gray

<#
$limitedChanges = @(Get-ServiceNowChange -Number 'CHG%' -Paged -Limit 100 -MaxRecords 500)
Write-Host "Retrieved: $($limitedChanges.Count) changes (capped at 500)" -ForegroundColor Green
#>

Write-Host 'Expected: Stops after 500 records even if 10,000 exist' -ForegroundColor Yellow

# ============================================================================
# Demo 4: Memory-Efficient Pipeline Processing
# ============================================================================
Write-Host ''
Write-Host '=== Demo 4: Stream Processing (Pipeline) ===' -ForegroundColor Cyan
Write-Host 'Process records as they arrive (memory efficient)' -ForegroundColor Gray

<#
Get-ServiceNowChange -Number 'CHG%' -Paged -Limit 100 | ForEach-Object {
    $change = $_
    Write-Host "Processing: $($change.number) - $($change.short_description)"
    # Could save to DB, send to webhook, transform, etc. - one at a time
}
Write-Host "All records processed in streaming fashion" -ForegroundColor Green
#>

Write-Host 'Expected: Processes records one-at-a-time; never loads all in memory' -ForegroundColor Yellow

# ============================================================================
# Demo 5: Counting All Records (Scan Everything)
# ============================================================================
Write-Host ''
Write-Host '=== Demo 5: Count Total Records ===' -ForegroundColor Cyan
Write-Host 'Count total by fetching everything (useful for reporting)' -ForegroundColor Gray

<#
$count = @(Get-ServiceNowChange -Number 'CHG%' -Paged -Limit 100).Count
Write-Host "Total changes found: $count" -ForegroundColor Green
#>

Write-Host 'Expected: Total count even if ServiceNow doesn''t return count header' -ForegroundColor Yellow

# ============================================================================
# Pagination Design Summary
# ============================================================================
Write-Host ''
Write-Host '=== Pagination Design Summary ===' -ForegroundColor Magenta
Write-Host @"
  -Paged Switch:
    OFF (default)   → Single request, returns up to Limit records
    ON              → Auto-paginate; returns all records (or up to MaxRecords)

  -Limit Parameter:
    Batch size per request (default: 100 from config)
    Example: -Limit 50  → Fetch 50 at a time

  -MaxRecords Parameter:
    Cap total retrieval (only with -Paged)
    Example: -MaxRecords 500 → Stop after 500 total, even if more exist
    Omit (or 0) → Fetch all available

  Use Cases:
    • Get one page of results     → Get-ServiceNowChange -Number CHG001
    • Fetch all (streaming)       → Get-ServiceNowChange -Number CHG% -Paged
    • Cap retrieval              → Get-ServiceNowChange -Number CHG% -Paged -MaxRecords 1000
    • Process large datasets     → ... | Paged | ForEach-Object { ... }
"@ -ForegroundColor White

Write-Host 'Demo Complete!' -ForegroundColor Green
