# Resolve the path to the OrgCodingHoursCLI executable (assumes the project is built)


Describe "OrgCodingHoursCLI" {

    BeforeAll {
        # Resolve path to CLI
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        $script:cliExePath = Join-Path $repoRoot "OrgCodingHoursCLI/bin/Release/net7.0/OrgCodingHoursCLI"
        if (-not (Test-Path $script:cliExePath)) {
            $script:cliExePath = Join-Path $repoRoot "OrgCodingHoursCLI/bin/Debug/net7.0/OrgCodingHoursCLI"
        }
        if ($IsWindows) { $script:cliExePath += ".exe" }

        # Create a minimal local git repository and configure git to use it
        $script:fixturesRoot = Join-Path ([System.IO.Path]::GetTempPath()) "git-fixtures"
        if (Test-Path $fixturesRoot) { Remove-Item -Recurse -Force $fixturesRoot }
        $srcDir = Join-Path $fixturesRoot "src"
        git init $srcDir | Out-Null
        git -C $srcDir config user.name "Alice"
        git -C $srcDir config user.email "alice@example.com"
        Set-Content -Path (Join-Path $srcDir "README.md") "hello"
        git -C $srcDir add README.md
        git -C $srcDir commit -m "Initial commit" --date="2023-01-01T00:00:00" | Out-Null
        git -C $srcDir config user.name "Bob"
        git -C $srcDir config user.email "bob@example.com"
        Add-Content -Path (Join-Path $srcDir "README.md") "`nmore"
        git -C $srcDir add README.md
        git -C $srcDir commit -m "Second commit" --date="2023-01-02T00:00:00" | Out-Null
        $bareDir = Join-Path $fixturesRoot "local"
        New-Item -ItemType Directory -Path $bareDir | Out-Null
        $script:bareRepo = Join-Path $bareDir "fixture.git"
        git clone --bare $srcDir $bareRepo | Out-Null
        git config --global ("url." + $fixturesRoot + "/.insteadOf") "https://github.com/"

        # Stub git-hours to return deterministic JSON
        $script:oldPath = $env:PATH
        $fakeGitHours = Join-Path $fixturesRoot "git-hours"
        @'
#!/bin/bash
echo '{"total":{"hours":0,"commits":2},"Alice":{"hours":0,"commits":1},"Bob":{"hours":0,"commits":1}}'
'@ | Set-Content -Path $fakeGitHours
        chmod +x $fakeGitHours
        $env:PATH = $fixturesRoot + [IO.Path]::PathSeparator + $env:PATH
    }

    AfterAll {
        git config --global --unset-all ("url." + $fixturesRoot + "/.insteadOf") 2>$null
        $env:PATH = $script:oldPath
        Remove-Item -Recurse -Force $fixturesRoot -ErrorAction SilentlyContinue
    }

    BeforeEach {
        # Clear environment variables and previous output between tests
        Remove-Item Env:REPOS -ErrorAction SilentlyContinue
        Remove-Item Env:GITHUB_OUTPUT -ErrorAction SilentlyContinue
        if (Test-Path "reports") { Remove-Item -Recurse -Force "reports" }
    }
    AfterEach {
        # Clean up environment variables and output after each test
        Remove-Item Env:REPOS -ErrorAction SilentlyContinue
        Remove-Item Env:GITHUB_OUTPUT -ErrorAction SilentlyContinue
        if (Test-Path "reports") { Remove-Item -Recurse -Force "reports" }
    }

    Context "When provided a valid repository input" {

        It "runs successfully and generates a JSON report for the repository" {
            # Arrange
            $env:REPOS = "local/fixture"  # Use the local fixture repo as input

            # Act
            $null = & $script:cliExePath   # Execute the CLI (suppress direct console output)

            # Assert: The CLI should exit successfully (exit code 0)
            $LASTEXITCODE | Should -Be 0

            # The 'reports' directory should be created and contain JSON output files
            Test-Path "reports" | Should -Be $true

            # There should be an aggregated JSON report file (filename includes 'aggregated')
            $aggReportFiles = Get-ChildItem -Path "reports" -Filter "*aggregated*.json"
            $aggReportFiles | Should -Not -BeNullOrEmpty   # aggregated report file exists

            # There should be an individual repo JSON report file for the fixture repo (slug: local_fixture)
            $repoReportFiles = Get-ChildItem -Path "reports" -Filter "*local_fixture*.json"
            $repoReportFiles | Should -Not -BeNullOrEmpty  # individual repo report exists

            # Load and inspect the aggregated JSON content
            $aggReport = Get-Content -Raw -Path $aggReportFiles[0].FullName | ConvertFrom-Json
            # The aggregated JSON should have a 'total' object and per-contributor entries:contentReference[oaicite:1]{index=1}
            ($aggReport.PSObject.Properties.Name -contains 'total') | Should -Be $true
            $aggReport.total.hours   | Should -Not -Be $null
            $aggReport.total.commits | Should -Not -Be $null

            # There should be at least one contributor entry (aside from 'total')
            ($aggReport.PSObject.Properties.Name | Where-Object { $_ -ne 'total' }) | Should -Not -BeNullOrEmpty

            # Verify that total commits equal the sum of commits from all contributors
            $totalCommits = $aggReport.total.commits
            $sumCommits   = ($aggReport.PSObject.Properties.Name | Where-Object { $_ -ne 'total' } | 
                              ForEach-Object { $aggReport.$_.commits }) | Measure-Object -Sum
            $sumCommits.Sum | Should -Be $totalCommits

            # Verify that total hours equal the sum of hours from all contributors (within a rounding tolerance)
            $totalHours = [double]$aggReport.total.hours
            $sumHours   = ($aggReport.PSObject.Properties.Name | Where-Object { $_ -ne 'total' } | 
                            ForEach-Object { [double]$aggReport.$_.hours }) | Measure-Object -Sum
            [Math]::Round($sumHours.Sum, 2) | Should -Be ([Math]::Round($totalHours, 2))
        }

        It "writes GitHub Actions outputs for aggregated_report and repo_slug" {
            # Arrange
            $env:REPOS = "local/fixture"
            # Simulate GitHub Actions output capturing by using a temporary file
            $tempOutputFile = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString() + ".txt")
            $env:GITHUB_OUTPUT = $tempOutputFile

            # Act
            $null = & $script:cliExePath

            # Assert: The outputs file should exist and contain the expected output lines
            Test-Path $tempOutputFile | Should -Be $true
            $outputLines = Get-Content -Path $tempOutputFile
            # The outputs should include lines for both 'aggregated_report' and 'repo_slug'
            $aggLine = $outputLines | Where-Object { $_.StartsWith("aggregated_report=") }
            $slugLine = $outputLines | Where-Object { $_.StartsWith("repo_slug=") }
            $aggLine  | Should -Not -Be $null
            $slugLine | Should -Not -Be $null

            # Extract the values from the output lines
            $aggLine -match '^aggregated_report=(.+)$' | Out-Null
            $outputPath = $Matches[1]
            $slugLine -match '^repo_slug=(.+)$' | Out-Null
            $outputSlug = $Matches[1]

            # The repo_slug output should be a slugified identifier of the repo list:contentReference[oaicite:2]{index=2}
            $outputSlug | Should -Be 'local_fixture'   # expected slug for local repo
            # The aggregated_report output should point to an existing JSON file in the workspace
            Test-Path $outputPath | Should -Be $true
            # (Optional) Verify the pointed JSON file has a 'total' field (basic sanity check on content)
            $outJson = Get-Content -Raw -Path $outputPath | ConvertFrom-Json
            ($outJson.PSObject.Properties.Name -contains 'total') | Should -Be $true
        }

    }
}
