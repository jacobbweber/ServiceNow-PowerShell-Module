## Simple performance metrics collector for ServiceNow operations

if (-not $script:ServiceNowMetrics) {
    $script:ServiceNowMetrics = [ordered]@{
        Requests = 0
        TotalMs = 0
        Operations = @{}
    }
}

function Start-ServiceNowTimer {
    [CmdletBinding()]
    param()
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    return $sw
}

function Stop-ServiceNowTimer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][System.Diagnostics.Stopwatch]$Stopwatch,
        [Parameter(Mandatory=$true)][string]$OperationKey,
        [string]$Status = 'Unknown'
    )
    $Stopwatch.Stop()
    $ms = [int]$Stopwatch.Elapsed.TotalMilliseconds

    # update global metrics
    if (-not $script:ServiceNowMetrics) {
        $script:ServiceNowMetrics = [ordered]@{ Requests = 0; TotalMs = 0; Operations = @{} }
    }
    $script:ServiceNowMetrics.Requests += 1
    $script:ServiceNowMetrics.TotalMs += $ms
    if (-not $script:ServiceNowMetrics.Operations.ContainsKey($OperationKey)) {
        $script:ServiceNowMetrics.Operations[$OperationKey] = [ordered]@{ Count = 0; TotalMs = 0 }
    }
    $op = $script:ServiceNowMetrics.Operations[$OperationKey]
    $op.Count += 1
    $op.TotalMs += $ms

    # return a simple object for convenience
    return [pscustomobject]@{ Operation = $OperationKey; DurationMs = $ms; Status = $Status }
}

function Get-ServiceNowMetrics {
    [CmdletBinding()]
    param()
    if (-not $script:ServiceNowMetrics) { return $null }
    return $script:ServiceNowMetrics
}

function Reset-ServiceNowMetrics {
    [CmdletBinding()]
    param()
    $script:ServiceNowMetrics = [ordered]@{ Requests = 0; TotalMs = 0; Operations = @{} }
    return $true
}
