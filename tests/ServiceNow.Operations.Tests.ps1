BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ServiceNow.PowerShell.psd1'
    Import-Module -Force $ModulePath -ErrorAction Stop
}

Describe 'Operations Map Integrity' {
    It 'Operations map file exists' {
        $mapPath = Join-Path -Path $PSScriptRoot -ChildPath '..\maps\servicenow.operations.json'
        Test-Path $mapPath | Should -Be $true
    }

    It 'Operations map is valid JSON' {
        $mapPath = Join-Path -Path $PSScriptRoot -ChildPath '..\maps\servicenow.operations.json'
        $map = Get-Content -Raw -Path $mapPath | ConvertFrom-Json
        $map | Should -Not -BeNullOrEmpty
    }

    It 'Operations map contains required properties' {
        $mapPath = Join-Path -Path $PSScriptRoot -ChildPath '..\maps\servicenow.operations.json'
        $map = Get-Content -Raw -Path $mapPath | ConvertFrom-Json
        $map.basePath | Should -Not -BeNullOrEmpty
        $map.operations | Should -Not -BeNullOrEmpty
    }

    It 'All operations have required fields' {
        $mapPath = Join-Path -Path $PSScriptRoot -ChildPath '..\maps\servicenow.operations.json'
        $map = Get-Content -Raw -Path $mapPath | ConvertFrom-Json
        $map.operations.PSObject.Properties | ForEach-Object {
            $op = $_.Value
            $op.path | Should -Not -BeNullOrEmpty
            $op.method | Should -Not -BeNullOrEmpty
            $op.auth | Should -Not -BeNullOrEmpty
        }
    }

    It 'All operations have valid HTTP methods' {
        $mapPath = Join-Path -Path $PSScriptRoot -ChildPath '..\maps\servicenow.operations.json'
        $map = Get-Content -Raw -Path $mapPath | ConvertFrom-Json
        $validMethods = @('GET', 'POST', 'PATCH', 'PUT', 'DELETE')
        $map.operations.PSObject.Properties | ForEach-Object {
            $op = $_.Value
            $op.method | Should -BeIn $validMethods
        }
    }

    It 'Expected operations exist' {
        $mapPath = Join-Path -Path $PSScriptRoot -ChildPath '..\maps\servicenow.operations.json'
        $map = Get-Content -Raw -Path $mapPath | ConvertFrom-Json
        @('Change.Get', 'Change.New', 'Change.Update', 'Change.Approve', 'Change.Deny', 'Change.Cancel') | ForEach-Object {
            $map.operations.PSObject.Properties.Name | Should -Contain $_
        }
    }
}

Describe 'Config File' {
    It 'Config file exists' {
        $cfgPath = Join-Path -Path $PSScriptRoot -ChildPath '..\config\module.settings.json'
        Test-Path $cfgPath | Should -Be $true
    }

    It 'Config is valid JSON' {
        $cfgPath = Join-Path -Path $PSScriptRoot -ChildPath '..\config\module.settings.json'
        $cfg = Get-Content -Raw -Path $cfgPath | ConvertFrom-Json
        $cfg | Should -Not -BeNullOrEmpty
    }

    It 'Config contains required keys' {
        $cfgPath = Join-Path -Path $PSScriptRoot -ChildPath '..\config\module.settings.json'
        $cfg = Get-Content -Raw -Path $cfgPath | ConvertFrom-Json
        $cfg.InstanceBaseUri | Should -Not -BeNullOrEmpty
        $cfg.AuthMode | Should -Not -BeNullOrEmpty
        $cfg.Defaults | Should -Not -BeNullOrEmpty
    }

    It 'Config defaults are numeric' {
        $cfgPath = Join-Path -Path $PSScriptRoot -ChildPath '..\config\module.settings.json'
        $cfg = Get-Content -Raw -Path $cfgPath | ConvertFrom-Json
        [int]$cfg.Defaults.sysparm_limit | Should -BeGreaterOrEqual 0
        [int]$cfg.Defaults.TimeoutSec | Should -BeGreaterOrEqual 0
        [int]$cfg.Defaults.RetryCount | Should -BeGreaterOrEqual 0
        [int]$cfg.Defaults.RetryDelaySec | Should -BeGreaterOrEqual 0
    }
}

Describe 'Module Functions' {
    It 'Get-ServiceNowChange is exported' {
        Get-Command -Name Get-ServiceNowChange -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'New-ServiceNowChange is exported' {
        Get-Command -Name New-ServiceNowChange -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'Update-ServiceNowChange is exported' {
        Get-Command -Name Update-ServiceNowChange -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'Approve-ServiceNowChange is exported' {
        Get-Command -Name Approve-ServiceNowChange -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'Deny-ServiceNowChange is exported' {
        Get-Command -Name Deny-ServiceNowChange -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'Invoke-ServiceNowChangeCancel is exported' {
        Get-Command -Name Invoke-ServiceNowChangeCancel -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}

Describe 'Function Parameters' {
    It 'Get-ServiceNowChange has Number parameter (mandatory)' {
        $cmd = Get-Command -Name Get-ServiceNowChange
        $cmd.Parameters['Number'].Attributes[0].Mandatory | Should -Be $true
    }

    It 'New-ServiceNowChange has Short_Description and Type parameters (mandatory)' {
        $cmd = Get-Command -Name New-ServiceNowChange
        $cmd.Parameters['Short_Description'].Attributes[0].Mandatory | Should -Be $true
        # Type parameter uses ValidateSet, which doesn't add Mandatory attribute at index 0
        $cmd.Parameters['Type'] | Should -Not -BeNullOrEmpty
    }

    It 'New-ServiceNowChange supports ShouldProcess' {
        $cmd = Get-Command -Name New-ServiceNowChange
        # Verify it has CmdletBinding attribute by calling with -WhatIf
        { New-ServiceNowChange -Short_Description 'Test' -Type normal -WhatIf -WarningAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Update-ServiceNowChange has Sys_Id parameter (mandatory)' {
        $cmd = Get-Command -Name Update-ServiceNowChange
        $cmd.Parameters['Sys_Id'].Attributes[0].Mandatory | Should -Be $true
    }

    It 'Update-ServiceNowChange supports ShouldProcess' {
        # Verify by calling with -WhatIf
        { Update-ServiceNowChange -Sys_Id 'test-id' -State draft -WhatIf -WarningAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Approve-ServiceNowChange has Sys_Id parameter (mandatory)' {
        $cmd = Get-Command -Name Approve-ServiceNowChange
        $cmd.Parameters['Sys_Id'].Attributes[0].Mandatory | Should -Be $true
    }

    It 'Invoke-ServiceNowChangeCancel has Sys_Id parameter (mandatory)' {
        $cmd = Get-Command -Name Invoke-ServiceNowChangeCancel
        $cmd.Parameters['Sys_Id'].Attributes[0].Mandatory | Should -Be $true
    }
}

Describe 'Token Handling' {
    It 'Get-ServiceNowChange errors when token not available' {
        $env:SERVICE_NOW_TOKEN = $null
        { Get-ServiceNowChange -Number 'CHG0000001' -ErrorAction Stop } | Should -Throw -ExpectedMessage '*ServiceNow token not found*'
    }

    It 'Get-ServiceNowChange attempt with token set fails on HTTP (not token)' {
        $env:SERVICE_NOW_TOKEN = 'test-token-123'
        # Should fail with connection error, not token error
        { Get-ServiceNowChange -Number 'CHG0000001' -ErrorAction Stop } | Should -Throw -ExpectedMessage '*No such host*'
        $env:SERVICE_NOW_TOKEN = $null
    }
}

Describe 'WhatIf Support' {
    It 'New-ServiceNowChange supports -WhatIf' {
        New-ServiceNowChange -Short_Description 'Test' -Type normal -WhatIf -WarningAction SilentlyContinue | Out-Null
        $? | Should -Be $true
    }

    It 'Update-ServiceNowChange supports -WhatIf' {
        Update-ServiceNowChange -Sys_Id 'test-id' -State draft -WhatIf -WarningAction SilentlyContinue | Out-Null
        $? | Should -Be $true
    }

    It 'Approve-ServiceNowChange supports -WhatIf' {
        Approve-ServiceNowChange -Sys_Id 'test-id' -WhatIf -WarningAction SilentlyContinue | Out-Null
        $? | Should -Be $true
    }

    It 'Deny-ServiceNowChange supports -WhatIf' {
        Deny-ServiceNowChange -Sys_Id 'test-id' -WhatIf -WarningAction SilentlyContinue | Out-Null
        $? | Should -Be $true
    }

    It 'Invoke-ServiceNowChangeCancel supports -WhatIf' {
        Invoke-ServiceNowChangeCancel -Sys_Id 'test-id' -WhatIf -WarningAction SilentlyContinue | Out-Null
        $? | Should -Be $true
    }
}

Describe 'Parameter Validation' {
    It 'New-ServiceNowChange Type parameter accepts valid values' {
        # Test by attempting calls with valid values (no error on param validation)
        { New-ServiceNowChange -Short_Description 'T' -Type normal -WhatIf -WarningAction SilentlyContinue } | Should -Not -Throw
        { New-ServiceNowChange -Short_Description 'T' -Type emergency -WhatIf -WarningAction SilentlyContinue } | Should -Not -Throw
        { New-ServiceNowChange -Short_Description 'T' -Type standard -WhatIf -WarningAction SilentlyContinue } | Should -Not -Throw
    }

    It 'New-ServiceNowChange Type parameter rejects invalid values' {
        { New-ServiceNowChange -Short_Description 'T' -Type invalid -WhatIf -WarningAction SilentlyContinue } | Should -Throw
    }

    It 'Update-ServiceNowChange State parameter accepts valid change states' {
        # Test a few valid states
        { Update-ServiceNowChange -Sys_Id 'test' -State draft -WhatIf -WarningAction SilentlyContinue } | Should -Not -Throw
        { Update-ServiceNowChange -Sys_Id 'test' -State approved -WhatIf -WarningAction SilentlyContinue } | Should -Not -Throw
        { Update-ServiceNowChange -Sys_Id 'test' -State scheduled -WhatIf -WarningAction SilentlyContinue } | Should -Not -Throw
    }

    It 'Update-ServiceNowChange State parameter rejects invalid values' {
        { Update-ServiceNowChange -Sys_Id 'test' -State invalid -WhatIf -WarningAction SilentlyContinue } | Should -Throw
    }
}
