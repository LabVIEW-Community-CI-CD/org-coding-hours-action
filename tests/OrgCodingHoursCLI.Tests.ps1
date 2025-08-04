# Resolve the path to the OrgCodingHoursCLI executable (assumes the project is built)
Set-Variable -Name repoRoot -Value (Split-Path -Path $PSScriptRoot -Parent) -Scope Script

# Prefer net8.0 builds but fall back to net7.0 if present
$candidatePaths = @(
    "OrgCodingHoursCLI/bin/Release/net8.0/OrgCodingHoursCLI",
    "OrgCodingHoursCLI/bin/Debug/net8.0/OrgCodingHoursCLI",
    "OrgCodingHoursCLI/bin/Release/net7.0/OrgCodingHoursCLI",
    "OrgCodingHoursCLI/bin/Debug/net7.0/OrgCodingHoursCLI"
)

foreach ($relativePath in $candidatePaths) {
    $possible = Join-Path $repoRoot $relativePath
    if (Test-Path $possible) {
        Set-Variable -Name cliExePath -Value $possible -Scope Script
        break
    }
}

if (-not $script:cliExePath) {
    throw "Unable to locate OrgCodingHoursCLI executable. Please build the project."
}

if ($IsWindows) { $script:cliExePath += ".exe" }

Describe "OrgCodingHoursCLI" {

    BeforeAll {
        # Provide a lightweight git-hours stub for tests
        $env:GIT_TERMINAL_PROMPT = '0'
        if (-not (Get-Command git-hours -ErrorAction SilentlyContinue)) {
            $gitHoursDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $gitHoursDir | Out-Null
            if ($IsWindows) {
                $gitHoursFile = Join-Path $gitHoursDir 'git-hours.cmd'
                $scriptContent = @"
@echo off
set args=%*
echo %args% | find "2999-01-01" >nul
if %errorlevel%==0 (
  echo {"total":{"hours":0,"commits":0}}
) else (
  echo {"alice":{"hours":1,"commits":1},"total":{"hours":1,"commits":1}}
)
"@
                Set-Content -Path $gitHoursFile -Value $scriptContent -NoNewline
            } else {
                $gitHoursFile = Join-Path $gitHoursDir 'git-hours'
                $scriptContent = @'
#!/bin/sh
if echo "$@" | grep -q "2999-01-01"; then
  echo '{"total":{"hours":0,"commits":0}}'
else
  echo '{"alice":{"hours":1,"commits":1},"total":{"hours":1,"commits":1}}'
fi
'@
                Set-Content -Path $gitHoursFile -Value $scriptContent -NoNewline
                chmod +x $gitHoursFile
            }
            $env:PATH = "$gitHoursDir$([IO.Path]::PathSeparator)$env:PATH"
        }
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
            $env:REPOS = "octocat/Hello-World"  # Use a sample public repo as input

            # Act
            $null = & $cliExePath   # Execute the CLI (suppress direct console output)

            # Assert: The CLI should exit successfully (exit code 0)
            $LASTEXITCODE | Should -Be 0

            # The 'reports' directory should be created and contain JSON output files
            Test-Path "reports" | Should -Be $true

            # There should be an aggregated JSON report file (filename includes 'aggregated')
            $aggReportFiles = Get-ChildItem -Path "reports" -Filter "*aggregated*.json"
            $aggReportFiles | Should -Not -BeNullOrEmpty   # aggregated report file exists

            # There should be an individual repo JSON report file for the repo (slug: octocat_Hello-World)
            $repoReportFiles = Get-ChildItem -Path "reports" -Filter "*octocat_Hello-World*.json"
            $repoReportFiles | Should -Not -BeNullOrEmpty  # individual repo report exists

            # Load and inspect the aggregated JSON content
            $aggReport = Get-Content -Raw -Path $aggReportFiles[0].FullName | ConvertFrom-Json
            # The aggregated JSON should have a 'total' object and per-contributor entries
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
              $env:REPOS = "octocat/Hello-World"
            # Simulate GitHub Actions output capturing by using a temporary file
            $tempOutputFile = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString() + ".txt")
            $env:GITHUB_OUTPUT = $tempOutputFile

            # Act
            $null = & $cliExePath

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

            # The repo_slug output should be a slugified identifier of the repo list
              $outputSlug | Should -Be 'octocat_Hello-World'   # expected slug for sample repo
            # The aggregated_report output should point to an existing JSON file in the workspace
            Test-Path $outputPath | Should -Be $true
            # (Optional) Verify the pointed JSON file has a 'total' field (basic sanity check on content)
            $outJson = Get-Content -Raw -Path $outputPath | ConvertFrom-Json
            ($outJson.PSObject.Properties.Name -contains 'total') | Should -Be $true
        }

        Context "WINDOW_START filtering" {
            It "includes commits when WINDOW_START is before history" {
                $env:REPOS = "octocat/Hello-World"
                $env:WINDOW_START = "1970-01-01"
                $null = & $cliExePath
                $LASTEXITCODE | Should -Be 0
                $agg = Get-Content -Raw -Path (Get-ChildItem reports/*aggregated*.json).FullName | ConvertFrom-Json
                $agg.total.commits | Should -BeGreaterThan 0
            }
            It "produces zero commits when WINDOW_START is after last commit" {
                $env:REPOS = "octocat/Hello-World"
                $env:WINDOW_START = "2999-01-01"
                $null = & $cliExePath
                $agg = Get-Content -Raw -Path (Get-ChildItem reports/*aggregated*.json).FullName | ConvertFrom-Json
                $agg.total.commits | Should -Be 0
            }
        }

        Context "Multiple repositories" {
            It "aggregates results and concatenates slugs" {
                  $env:REPOS = "octocat/Hello-World octocat/Spoon-Knife"
                $tempOutputFile = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString() + ".txt")
                $env:GITHUB_OUTPUT = $tempOutputFile
                $null = & $cliExePath
                $LASTEXITCODE | Should -Be 0
                $files = Get-ChildItem reports -Filter "*.json"
                ($files | Where-Object { $_.Name -like '*aggregated*' }).Count | Should -Be 1
                  ($files | Where-Object { $_.Name -like '*octocat_Hello-World*' }).Count | Should -Be 1
                  ($files | Where-Object { $_.Name -like '*octocat_Spoon-Knife*' }).Count | Should -Be 1
                  $agg = Get-Content -Raw -Path (Get-ChildItem reports/*aggregated*.json).FullName | ConvertFrom-Json
                  $r1 = Get-Content -Raw -Path (Get-ChildItem reports/*octocat_Hello-World*.json).FullName | ConvertFrom-Json
                  $r2 = Get-Content -Raw -Path (Get-ChildItem reports/*octocat_Spoon-Knife*.json).FullName | ConvertFrom-Json
                  $agg.total.commits | Should -Be ($r1.total.commits + $r2.total.commits)
                  $outLines = Get-Content -Path $tempOutputFile
                  ($outLines | Where-Object { $_ -like 'repo_slug=*' }) -match 'repo_slug=(.+)' | Out-Null
                  $Matches[1] | Should -Be 'octocat_Hello-World-octocat_Spoon-Knife'
            }
        }

        Context "Docker image" {
            $hasDocker = Get-Command docker -ErrorAction SilentlyContinue
            It "contains the CLI executable" -Skip:(!$hasDocker) {
                $repoRoot = Split-Path -Path $PSScriptRoot -Parent
                $versionFile = Join-Path $repoRoot 'version.props'
                $version = ([xml](Get-Content -Path $versionFile)).Project.PropertyGroup.Version
                docker build --build-arg CLI_VERSION=$version -t "org-hours-test:$version" $repoRoot | Out-Null
                docker run --rm "org-hours-test:$version" /bin/sh -c 'test -f /app/OrgCodingHoursCLI.dll' | Out-Null
                docker run --rm "org-hours-test:$version" --help 2>&1 | Should -Match "REPOS"
            }
        }

    }
}