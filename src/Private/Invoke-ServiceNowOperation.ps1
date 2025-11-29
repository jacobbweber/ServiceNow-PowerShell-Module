function Get-OperationDefinition {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Key
    )
    if (-not $script:ServiceNowOperations) {
        $mapPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\maps\servicenow.operations.json"
        if (-not (Test-Path $mapPath)) { throw "Operations map not found at $mapPath" }
        $script:ServiceNowOperations = Get-Content -Raw -Path $mapPath | ConvertFrom-Json
    }
    return $script:ServiceNowOperations.operations.$Key
}

function Convert-ServiceNowTokens {
    param(
        [Parameter(Mandatory=$true)][object]$Template,
        [Parameter()][hashtable]$Params
    )
    if ($null -eq $Template) { return $null }
    if ($Template -is [string]) {
        $s = $Template
        foreach ($k in $Params.Keys) {
            $s = $s -replace "\{${k}\}", [string]$Params[$k]
        }
        return $s
    }
    if ($Template -is [System.Management.Automation.PSObject] -or $Template -is [hashtable]) {
        $result = @{}
        foreach ($p in $Template.PSObject.Properties) {
            $val = $p.Value
            $newVal = Convert-ServiceNowTokens -Template $val -Params $Params
            $result[$p.Name] = $newVal
        }
        return $result
    }
    if ($Template -is [object[]]) {
        return $Template | ForEach-Object { Convert-ServiceNowTokens -Template $_ -Params $Params }
    }
    return $Template
}

function Build-QueryString {
    param(
        [Parameter(Mandatory=$true)][psobject]$Operation,
        [Parameter()]
        [hashtable]$Params,
        [Parameter()]
        [hashtable]$Options
    )
    $qsPairs = @{}
    if ($Operation.query) {
        $templ = Convert-ServiceNowTokens -Template $Operation.query -Params $Params
        foreach ($p in $templ.Keys) { if ($null -ne $templ[$p]) { $qsPairs[$p] = $templ[$p] } }
    }
    if ($Options -and $Options.Query) {
        foreach ($k in $Options.Query.Keys) { $qsPairs[$k] = $Options.Query[$k] }
    }
    # apply module defaults for sysparm_limit if not provided
    if (-not $qsPairs.sysparm_limit) {
        $defaultLimit = Get-ModuleSetting -Key 'Defaults.sysparm_limit'
        if ($defaultLimit) { $qsPairs.sysparm_limit = $defaultLimit }
    }
    if ($qsPairs.Keys.Count -eq 0) { return '' }
    $encoded = $qsPairs.GetEnumerator() | ForEach-Object { "{0}={1}" -f [uri]::EscapeDataString($_.Key), [uri]::EscapeDataString([string]$_.Value) }
    return "?" + ($encoded -join '&')
}

function Build-ServiceNowUri {
    param(
        [Parameter(Mandatory=$true)][psobject]$Operation,
        [Parameter()]
        [hashtable]$Params,
        [Parameter()]
        [hashtable]$Options
    )
    $base = Get-ModuleSetting -Key 'InstanceBaseUri'
    if (-not $base) { throw 'InstanceBaseUri not set. Use Set-ModuleSetting to configure.' }
    $basePath = $script:ServiceNowOperations.basePath
    $pathTemplate = $Operation.path
    $path = Convert-ServiceNowTokens -Template $pathTemplate -Params $Params
    $qs = Build-QueryString -Operation $Operation -Params $Params -Options $Options
    return ($base.TrimEnd('/') + $basePath + $path + $qs)
}

function Get-ServiceNowToken {
    param()
    # Prefer SecretManagement, then environment variable, then config (not secure)
    # Try SecretManagement's Get-Secret if available
    if (Get-Command -Name Get-Secret -ErrorAction SilentlyContinue) {
        try {
            $sec = Get-Secret -Name 'ServiceNowToken' -ErrorAction Stop
            if ($null -ne $sec) {
                if ($sec -is [System.Security.SecureString]) {
                    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
                    try { $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
                    return $plain
                } elseif ($sec -is [System.Management.Automation.PSCredential]) {
                    return $sec.GetNetworkCredential().Password
                } else {
                    return [string]$sec
                }
            }
        } catch {
            # ignore and fall through to other methods
        }
    }
    # Fallback to environment variable
    if ($env:SERVICE_NOW_TOKEN) { return $env:SERVICE_NOW_TOKEN }
    # Fallback to config (not secure)
    $token = Get-ModuleSetting -Key 'Token'
    if ($token) { return $token }
    throw 'ServiceNow token not found. Use Microsoft.PowerShell.SecretManagement Set-Secret -Name ServiceNowToken, set environment variable SERVICE_NOW_TOKEN, or use Set-ModuleSetting -Key Token -Value <token>'
}

function Set-ServiceNowToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Token,
        [string]$Vault
    )
    # Prefer SecretManagement if available
    if (Get-Command -Name Set-Secret -ErrorAction SilentlyContinue) {
            try {
                # Build a SecureString from the plain string without using ConvertTo-SecureString -AsPlainText
                if ($Token -is [System.Security.SecureString]) {
                    $secure = $Token
                } elseif ($Token -is [System.Management.Automation.PSCredential]) {
                    $secure = $Token.GetNetworkCredential().Password | ForEach-Object {
                        $ss = New-Object System.Security.SecureString
                        foreach ($ch in $_.ToCharArray()) { $ss.AppendChar($ch) }
                        $ss.MakeReadOnly()
                        $ss
                    }
                } else {
                    $ss = New-Object System.Security.SecureString
                    foreach ($ch in $Token.ToCharArray()) { $ss.AppendChar($ch) }
                    $ss.MakeReadOnly()
                    $secure = $ss
                }
                if ($PSBoundParameters.ContainsKey('Vault')) {
                    Set-Secret -Name 'ServiceNowToken' -Secret $secure -Vault $Vault -ErrorAction Stop
                } else {
                    Set-Secret -Name 'ServiceNowToken' -Secret $secure -ErrorAction Stop
                }
                Write-Output 'Stored token in SecretManagement vault.'
                return
            } catch {
                Write-Warning "SecretManagement Set-Secret failed: $($_.Exception.Message)"
            }
    }
    # Fallback: store in module settings (not secure)
    Set-ModuleSetting -Key 'Token' -Value $Token
    Write-Warning 'SecretManagement not available; token stored in module settings (not secure).'
}

function Remove-ServiceNowToken {
    [CmdletBinding()]
    param(
        [string]$Vault
    )
    if (Get-Command -Name Remove-Secret -ErrorAction SilentlyContinue) {
        try {
            if ($PSBoundParameters.ContainsKey('Vault')) { Remove-Secret -Name 'ServiceNowToken' -Vault $Vault -ErrorAction Stop } else { Remove-Secret -Name 'ServiceNowToken' -ErrorAction Stop }
            Write-Output 'Removed ServiceNow token from SecretManagement vault.'
            return
        } catch {
            Write-Warning "Remove-Secret failed: $($_.Exception.Message)"
        }
    }
    # Fallback: remove from module settings
    Set-ModuleSetting -Key 'Token' -Value $null
    Write-Warning 'SecretManagement not available; cleared token from module settings.'
}

function Get-ServiceNowHeaders {
    param(
        [psobject]$Operation,
        [hashtable]$Options
    )
    $h = @{ Accept = 'application/json' }
    if ($Operation.auth -and $Operation.auth -eq 'Bearer') {
        $token = Get-ServiceNowToken
        $h['Authorization'] = "Bearer $token"
    }
    if ($Options -and $Options.Headers) {
        foreach ($k in $Options.Headers.Keys) { $h[$k] = $Options.Headers[$k] }
    }
    return $h
}

function Build-ServiceNowBody {
    param(
        [psobject]$Operation,
        [hashtable]$Params
    )
    if (-not $Operation.body) { return $null }
    $body = Convert-ServiceNowTokens -Template $Operation.body -Params $Params
    return $body
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory=$true)][scriptblock]$Action,
        [Parameter()][string]$ActionName = 'action',
        [int]$RetryCount = 3,
        [int]$RetryDelaySec = 2
    )
    for ($i = 0; $i -le $RetryCount; $i++) {
        try {
            return & $Action
        } catch {
            $err = $_
            $status = $null
            try { $status = $_.Exception.Response.StatusCode } catch { }
            $isRetryable = $true
            if ($i -eq $RetryCount) { throw $err }
            Start-Sleep -Seconds ($RetryDelaySec * [Math]::Pow(2, $i))
        }
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'INFO',
        [hashtable]$Context
    )
    $entry = @{ timestamp = (Get-Date).ToString('o'); level = $Level; message = $Message; context = $Context }
    $entry | ConvertTo-Json -Depth 4
}

function Invoke-ServiceNowOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$OperationKey,
        [Parameter()][hashtable]$Params = @{},
        [Parameter()][hashtable]$Options = @{}
    )
    $op = Get-OperationDefinition -Key $OperationKey
    if (-not $op) { throw "Operation '$OperationKey' not found in operations map." }

    $uri = Build-ServiceNowUri -Operation $op -Params $Params -Options $Options
    $headers = Get-ServiceNowHeaders -Operation $op -Options $Options
    $body = Build-ServiceNowBody -Operation $op -Params $Params

    $method = $op.method

    $retryCount = $Options.RetryCount -as [int]
    if (-not $retryCount) { $retryCount = (Get-ModuleSetting -Key 'Defaults.RetryCount') -as [int]; if (-not $retryCount) { $retryCount = 3 } }
    $retryDelay = $Options.RetryDelaySec -as [int]
    if (-not $retryDelay) { $retryDelay = (Get-ModuleSetting -Key 'Defaults.RetryDelaySec') -as [int]; if (-not $retryDelay) { $retryDelay = 2 } }

    $action = {
        if ($body) {
            $jsonBody = $body | ConvertTo-Json -Depth 6
        } else { $jsonBody = $null }
        $sw = Start-ServiceNowTimer
        $status = 'Unknown'
        try {
            Write-Log -Message "Calling ServiceNow $OperationKey" -Level Info -Context @{ Uri = $uri; Method = $method }
            $resp = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $jsonBody -ContentType 'application/json'
            $status = 'Success'
            return $resp
        } catch {
            $status = 'Error'
            throw $_
        } finally {
            try { Stop-ServiceNowTimer -Stopwatch $sw -OperationKey $OperationKey -Status $status | Out-Null } catch { }
        }
    }

    return Invoke-WithRetry -Action $action -ActionName "ServiceNow $OperationKey" -RetryCount $retryCount -RetryDelaySec $retryDelay
}
