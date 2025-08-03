# Resolve the path to the OrgCodingHoursCLI executable (same logic as in other test file)
Describe "OrgCodingHoursCLI Error Handling" {

    BeforeAll {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        $script:cliExePath = Join-Path $repoRoot "OrgCodingHoursCLI/bin/Release/net7.0/OrgCodingHoursCLI"
        if (-not (Test-Path $script:cliExePath)) {
            $script:cliExePath = Join-Path $repoRoot "OrgCodingHoursCLI/bin/Debug/net7.0/OrgCodingHoursCLI"
        }
        if ($IsWindows) { $script:cliExePath += ".exe" }
    }

    BeforeEach {
        # Ensure no required env vars are set and no leftover output
        Remove-Item Env:REPOS -ErrorAction SilentlyContinue
        Remove-Item Env:GITHUB_OUTPUT -ErrorAction SilentlyContinue
        if (Test-Path "reports") { Remove-Item -Recurse -Force "reports" }
    }
    AfterEach {
        # Clean up after test
        Remove-Item Env:REPOS -ErrorAction SilentlyContinue
        Remove-Item Env:GITHUB_OUTPUT -ErrorAction SilentlyContinue
        if (Test-Path "reports") { Remove-Item -Recurse -Force "reports" }
    }

    It "fails with a non-zero exit code and an error message when REPOS is not provided" {
        # Arrange: (Do not set $env:REPOS to simulate missing input)
        Remove-Item Env:REPOS -ErrorAction SilentlyContinue

        # Act: Run the CLI without the required REPOS input, capturing any error output
        $result = & $script:cliExePath 2>&1
        $exitCode = $LASTEXITCODE

        # Assert: The CLI should exit with an error (non-zero exit code)
        $exitCode | Should -Not -Be 0
        # It should produce an error message indicating that REPOS is missing
        $result | Should -Match "REPOS"   # Expect the error output to mention the missing 'REPOS' variable
    }
}
