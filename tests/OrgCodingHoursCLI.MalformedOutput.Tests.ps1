# File: tests/OrgCodingHoursCLI.MalformedOutput.Tests.ps1
# Resolve the path to the OrgCodingHoursCLI executable (same logic as in other test files)
$repoRoot = Split-Path -Path $PSScriptRoot -Parent

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

# Preserve original PATH so we can restore it after injecting a dummy git-hours
$script:originalPath = $env:PATH
$script:dummyDir = $null

Describe "OrgCodingHoursCLI Malformed Output Handling" {

    BeforeEach {
        # Clear environment variables and any prior output
        Remove-Item Env:REPOS        -ErrorAction SilentlyContinue
        Remove-Item Env:GITHUB_OUTPUT -ErrorAction SilentlyContinue
        Remove-Item Env:GITHUB_TOKEN -ErrorAction SilentlyContinue
        if (Test-Path "reports") { Remove-Item -Recurse -Force "reports" }

        # Create a temporary directory and dummy git-hours script to simulate malformed JSON output
        $script:dummyDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:dummyDir | Out-Null

        if ($IsWindows) {
            $dummyExe = Join-Path $script:dummyDir "git-hours.cmd"
            # Batch script: suppress command echoing and output a non-JSON string
            Set-Content -Path $dummyExe -Value "@echo off`r`n@echo not a json" -Encoding ASCII
        }
        else {
            $dummyExe = Join-Path $script:dummyDir "git-hours"
            # Bash script: output a non-JSON string
            Set-Content -Path $dummyExe -Value "#!/usr/bin/env bash`necho 'not a json'" -Encoding ASCII
            chmod +x "$dummyExe"
        }

        # Prepend the dummy script directory to PATH so our dummy git-hours is invoked
        $env:PATH = "$script:dummyDir$([System.IO.Path]::PathSeparator)$($env:PATH)"
    }
    AfterEach {
        # Clean up environment variables and output
        Remove-Item Env:REPOS        -ErrorAction SilentlyContinue
        Remove-Item Env:GITHUB_OUTPUT -ErrorAction SilentlyContinue
        Remove-Item Env:GITHUB_TOKEN -ErrorAction SilentlyContinue
        if (Test-Path "reports") { Remove-Item -Recurse -Force "reports" }

        # Remove the dummy git-hours directory and restore the original PATH
        if (Test-Path $script:dummyDir) { Remove-Item -Recurse -Force $script:dummyDir }
        $env:PATH = $script:originalPath
    }

    It "fails with a non-zero exit code and an error message when git-hours returns malformed JSON" {
        # Arrange: provide a valid repo, but dummy git-hours will output bad JSON
        $env:REPOS = "octocat/Hello-World"

        # Act: Run the CLI, capturing output and the expected error
        $result   = & $cliExePath 2>&1
        $exitCode = $LASTEXITCODE

        # Assert: The CLI should fail (non-zero exit) and report a JSON parsing error
        $exitCode | Should -Not -Be 0
        $result   | Should -Match "invalid start of a value"  # Expect parse error mentioning malformed JSON
    }
}
