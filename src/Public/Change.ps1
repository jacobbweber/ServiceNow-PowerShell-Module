function Get-ServiceNowChange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Number,
        [string]$Fields,
        [int]$Limit,
        [switch]$Paged,
        [int]$MaxRecords,
        [switch]$Raw
    )
    $params = @{ number = $Number }
    $options = @{ }
    if ($Fields) { $options.Fields = $Fields }
    if ($Limit -and -not $Paged) { 
        $options.Query = @{ sysparm_limit = $Limit } 
    }
    
    if ($Paged) {
        # Use pagination helper to iterate through all results
        $batchSize = if ($Limit -gt 0) { $Limit } else { (Get-ModuleSetting -Key 'Defaults.sysparm_limit') ?? 100 }
        $maxRecs = if ($MaxRecords -gt 0) { $MaxRecords } else { 0 }
        Get-ServiceNowPaged -OperationKey 'Change.Get' -Params $params -Options $options -BatchSize $batchSize -MaxRecords $maxRecs
    } else {
        # Single request, non-paged
        $resp = Invoke-ServiceNowOperation -OperationKey 'Change.Get' -Params $params -Options $options
        if ($Raw) { return $resp } else { return $resp.result }
    }
}

function New-ServiceNowChange {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$Short_Description,
        [Parameter(Mandatory=$true)][ValidateSet('normal','emergency','standard')][string]$Type,
        [string]$Assignment_Group,
        [switch]$Raw
    )
    if ($PSCmdlet.ShouldProcess("Create change: $Short_Description")) {
        $params = @{ short_description = $Short_Description; type = $Type; assignment_group = $Assignment_Group }
        $resp = Invoke-ServiceNowOperation -OperationKey 'Change.New' -Params $params
        if ($Raw) { return $resp } else { return $resp.result }
    }
}

function Update-ServiceNowChange {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$Sys_Id,
        [ValidateSet('draft','submitted','pending','approved','rejected','scheduled','in_progress','implemented','closed','cancelled')][string]$State,
        [string]$Work_Notes,
        [switch]$Raw
    )
    if ($PSCmdlet.ShouldProcess("Update change: $Sys_Id")) {
        $params = @{ sys_id = $Sys_Id; state = $State; work_notes = $Work_Notes }
        $resp = Invoke-ServiceNowOperation -OperationKey 'Change.Update' -Params $params
        if ($Raw) { return $resp } else { return $resp.result }
    }
}

function Approve-ServiceNowChange {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$Sys_Id,
        [string]$Comments,
        [switch]$Raw
    )
    if ($PSCmdlet.ShouldProcess("Approve change: $Sys_Id")) {
        $params = @{ sys_id = $Sys_Id; comments = $Comments }
        $resp = Invoke-ServiceNowOperation -OperationKey 'Change.Approve' -Params $params
        if ($Raw) { return $resp } else { return $resp.result }
    }
}

function Deny-ServiceNowChange {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$Sys_Id,
        [string]$Comments,
        [switch]$Raw
    )
    if ($PSCmdlet.ShouldProcess("Deny change: $Sys_Id")) {
        $params = @{ sys_id = $Sys_Id; comments = $Comments }
        $resp = Invoke-ServiceNowOperation -OperationKey 'Change.Deny' -Params $params
        if ($Raw) { return $resp } else { return $resp.result }
    }
}

function Invoke-ServiceNowChangeCancel {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$Sys_Id,
        [string]$Reason,
        [switch]$Raw
    )
    if ($PSCmdlet.ShouldProcess("Cancel change: $Sys_Id")) {
        $params = @{ sys_id = $Sys_Id; reason = $Reason }
        $resp = Invoke-ServiceNowOperation -OperationKey 'Change.Cancel' -Params $params
        if ($Raw) { return $resp } else { return $resp.result }
    }
}
