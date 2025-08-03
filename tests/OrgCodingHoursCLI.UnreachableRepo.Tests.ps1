# File: tests/OrgCodingHoursCLI.UnreachableRepo.Tests.ps1
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

Describe "OrgCodingHoursCLI Unreachable Repo Handling" {

    BeforeEach {
        # Clear relevant environment and output from any previous tests
        Remove-Item Env:REPOS        -ErrorAction SilentlyContinue
        Remove-Item Env:GITHUB_OUTPUT -ErrorAction SilentlyContinue
        Remove-Item Env:GITHUB_TOKEN -ErrorAction SilentlyContinue
        if (Test-Path "reports") { Remove-Item -Recurse -Force "reports" }
    }
    AfterEach {
        # Clean up environment and output after each test
        Remove-Item Env:REPOS        -ErrorAction SilentlyContinue
        Remove-Item Env:GITHUB_OUTPUT -ErrorAction SilentlyContinue
        Remove-Item Env:GITHUB_TOKEN -ErrorAction SilentlyContinue
        if (Test-Path "reports") { Remove-Item -Recurse -Force "reports" }
    }

    It "fails with a non-zero exit code and an error message when repository cannot be cloned" {
        # Arrange: set an invalid repository name to force a clone failure
        $env:REPOS = "fake-user/nonexistent"

        # Act: Run the CLI, capturing all output (including errors)
        $result   = & $cliExePath 2>&1
        $exitCode = $LASTEXITCODE

        # Assert: The CLI should exit with an error and output an appropriate message
        $exitCode | Should -Not -Be 0
        $result   | Should -Match "not found"   # Expect error output to mention the repo was not found
    }
}
