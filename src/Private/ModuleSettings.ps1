function Get-ModuleSettingsPath {
    return Join-Path -Path $PSScriptRoot -ChildPath "..\..\config\module.settings.json"
}

function Get-ModuleSetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Key
    )
    $path = (Get-ModuleSettingsPath)
    if (-not (Test-Path $path)) { return $null }
    $json = Get-Content -Raw -Path $path | ConvertFrom-Json
    $parts = $Key -split '\.'
    $current = $json
    foreach ($p in $parts) {
        if ($null -eq $current) { return $null }
        if ($current.PSObject.Properties.Match($p)) {
            $current = $current.$p
        } else {
            return $null
        }
    }
    return $current
}

function Set-ModuleSetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Key,
        [Parameter(Mandatory=$true)]
        [object]$Value
    )
    $path = (Get-ModuleSettingsPath)
    $dir = Split-Path -Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $json = @{}
    if (Test-Path $path) { $json = Get-Content -Raw -Path $path | ConvertFrom-Json }
    # support top-level keys only or Defaults.*
    if ($Key -like '*.*') {
        $parts = $Key -split '\.'
        $root = $parts[0]
        $sub = $parts[1]
        if (-not $json.$root) { $json | Add-Member -MemberType NoteProperty -Name $root -Value @{} }
        $json.$root.$sub = $Value
    } else {
        $json.$Key = $Value
    }
    $json | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding UTF8
}
