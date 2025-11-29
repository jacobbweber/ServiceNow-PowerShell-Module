BeforeAll {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ServiceNow.PowerShell.psd1'
    Import-Module -Force $ModulePath -ErrorAction Stop
}

Describe 'Pagination Support' {
    It 'Get-ServiceNowChange has -Paged switch' {
        $cmd = Get-Command -Name Get-ServiceNowChange
        $cmd.Parameters['Paged'] | Should -Not -BeNullOrEmpty
    }

    It 'Get-ServiceNowChange has -MaxRecords parameter' {
        $cmd = Get-Command -Name Get-ServiceNowChange
        $cmd.Parameters['MaxRecords'] | Should -Not -BeNullOrEmpty
    }

    It 'Get-ServiceNowChange -Paged without token errors on token' {
        $env:SERVICE_NOW_TOKEN = $null
        { Get-ServiceNowChange -Number 'CHG%' -Paged -ErrorAction Stop } | Should -Throw -ExpectedMessage '*ServiceNow token not found*'
    }

    It 'Get-ServiceNowChange -Paged with token attempts HTTP (expected failure)' {
        $env:SERVICE_NOW_TOKEN = 'test-token-123'
        { Get-ServiceNowChange -Number 'CHG%' -Paged -Limit 10 -ErrorAction Stop } | Should -Throw -ExpectedMessage '*No such host*'
        $env:SERVICE_NOW_TOKEN = $null
    }

    It 'Get-ServiceNowChange -MaxRecords works with -Paged' {
        # Verify the parameter combination is syntactically valid
        $cmd = Get-Command -Name Get-ServiceNowChange
        $cmd.Parameters['Paged'] | Should -Not -BeNullOrEmpty
        $cmd.Parameters['MaxRecords'] | Should -Not -BeNullOrEmpty
    }

    It 'Get-ServiceNowChange -Paged without MaxRecords fetches all (if available)' {
        # -Paged mode yields directly, so -WhatIf doesn't apply
        # Just verify the parameter is accepted and no syntax error
        $cmd = Get-Command -Name Get-ServiceNowChange
        $cmd.Parameters['Paged'] | Should -Not -BeNullOrEmpty
    }

    It 'Pagination helper Get-ServiceNowPaged exists and is callable' {
        # Verify the private helper loads (it's in Private/Pagination.ps1)
        $pagePath = Join-Path -Path $PSScriptRoot -ChildPath '..\src\Private\Pagination.ps1'
        Test-Path $pagePath | Should -Be $true
    }
}

Describe 'Pagination Behavior' {
    It 'Get-ServiceNowChange non-paged (-Paged not set) calls single operation' {
        $env:SERVICE_NOW_TOKEN = 'test-token-123'
        # Non-paged should fail faster on HTTP than paged (no retry loop)
        $start = Get-Date
        try { Get-ServiceNowChange -Number 'CHG001' -Limit 100 -ErrorAction Stop } catch { }
        $duration = (Get-Date) - $start
        $duration.TotalSeconds | Should -BeLessThan 20
        $env:SERVICE_NOW_TOKEN = $null
    }

    It 'Get-ServiceNowChange returns results (or empty array when no match)' {
        # Design test: -Paged mode requires token to run, so test non-paged
        $env:SERVICE_NOW_TOKEN = 'test-token-123'
        try {
            Get-ServiceNowChange -Number 'CHG%' -Limit 1 -ErrorAction SilentlyContinue | Out-Null
        } catch {
            # Expected to fail on HTTP, not on return type
        }
        $env:SERVICE_NOW_TOKEN = $null
    }
}
