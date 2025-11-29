@{
    RootModule = 'ServiceNow.PowerShell.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'a7b8c9d0-e1f2-4a5b-8c6d-7e8f9a0b1c2d'
    Author = 'ServiceNow Module Dev'
    Description = 'PowerShell 7 module for ServiceNow Change Management API'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-ServiceNowChange',
        'New-ServiceNowChange',
        'Update-ServiceNowChange',
        'Approve-ServiceNowChange',
        'Deny-ServiceNowChange',
        'Invoke-ServiceNowChangeCancel',
        'Set-ServiceNowToken',
        'Remove-ServiceNowToken',
        'Get-ServiceNowMetrics',
        'Reset-ServiceNowMetrics'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('ServiceNow', 'API', 'ChangeManagement')
            ProjectUri = 'https://github.com/jacobbweber/ServiceNow.PowerShell'
        }
    }
}
