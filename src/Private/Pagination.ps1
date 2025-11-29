function Get-ServiceNowPaged {
    <#
    .SYNOPSIS
    Helper to retrieve paginated results from ServiceNow API.
    
    .DESCRIPTION
    Automatically handles sysparm_limit and sysparm_offset to iterate through all records.
    Yields results as they arrive, enabling pipeline-friendly processing.
    
    .PARAMETER OperationKey
    The operation key (e.g., 'Change.Get') to invoke repeatedly.
    
    .PARAMETER Params
    Base parameters for the operation (e.g., @{ number = 'CHG123' }).
    
    .PARAMETER Options
    Base options for the operation.
    
    .PARAMETER BatchSize
    Number of records per request (sysparm_limit). Default: 100.
    
    .PARAMETER MaxRecords
    Stop after retrieving this many records. Omit to fetch all.
    
    .EXAMPLE
    Get-ServiceNowPaged -OperationKey 'Change.Get' -Params @{} -BatchSize 100 -MaxRecords 500
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$OperationKey,
        [hashtable]$Params = @{},
        [hashtable]$Options = @{},
        [int]$BatchSize = 100,
        [int]$MaxRecords
    )
    
    $offset = 0
    $totalFetched = 0
    $hasMore = $true
    
    while ($hasMore) {
        # Respect MaxRecords limit
        if ($MaxRecords -and $totalFetched -ge $MaxRecords) { break }
        
        # Adjust batch size if we'd exceed MaxRecords
        $currentBatch = $BatchSize
        if ($MaxRecords -and ($totalFetched + $currentBatch) -gt $MaxRecords) {
            $currentBatch = $MaxRecords - $totalFetched
        }
        
        # Build pagination options
        $pagingOptions = $Options.Clone()
        if (-not $pagingOptions.Query) { $pagingOptions.Query = @{} }
        $pagingOptions.Query['sysparm_offset'] = $offset
        $pagingOptions.Query['sysparm_limit'] = $currentBatch
        
        # Fetch batch
        $resp = Invoke-ServiceNowOperation -OperationKey $OperationKey -Params $Params -Options $pagingOptions
        
        if (-not $resp -or -not $resp.result) {
            $hasMore = $false
            break
        }
        
        $records = @($resp.result)
        $fetched = $records.Count
        
        # Yield each record
        $records | ForEach-Object { $_ }
        
        $totalFetched += $fetched
        $offset += $fetched
        
        # Stop if fewer records than requested (end of data)
        if ($fetched -lt $currentBatch) { $hasMore = $false }
    }
}
