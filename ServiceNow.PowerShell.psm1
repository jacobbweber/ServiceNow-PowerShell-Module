# Module entry - dot-source private and public helpers
$script:ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Dot-source private helpers
Get-ChildItem -Path (Join-Path $script:ModuleRoot 'src\Private') -Filter *.ps1 | ForEach-Object { . $_.FullName }

# Load operations map into script variable for helpers
$mapPath = Join-Path -Path $script:ModuleRoot -ChildPath 'maps\servicenow.operations.json'
if (Test-Path $mapPath) { $script:ServiceNowOperations = Get-Content -Raw -Path $mapPath | ConvertFrom-Json }

# Dot-source public functions
Get-ChildItem -Path (Join-Path $script:ModuleRoot 'src\Public') -Filter *.ps1 | ForEach-Object { . $_.FullName }

Export-ModuleMember -Function *ServiceNow*
