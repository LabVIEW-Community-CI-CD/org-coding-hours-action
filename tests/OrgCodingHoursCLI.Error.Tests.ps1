# Resolve the path to the OrgCodingHoursCLI executable (same logic as in other test file)
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

Describe "OrgCodingHoursCLI Error Handling" {

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
        $result = & $cliExePath 2>&1
        $exitCode = $LASTEXITCODE

        # Assert: The CLI should exit with an error (non-zero exit code)
        $exitCode | Should -Not -Be 0
        # It should produce an error message indicating that REPOS is missing
        $result | Should -Match "REPOS"   # Expect the error output to mention the missing 'REPOS' variable
    }

    It "fails when repository slug is invalid" {
        $env:REPOS = "octocat/ThisRepoDoesNotExist"
        $result = & $cliExePath 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result | Should -Match "clone"
    }

    It "fails when git-hours returns non-zero" {
        $fakeDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $fakeDir | Out-Null
        $scriptPath = Join-Path $fakeDir "git-hours"
        Set-Content -Path $scriptPath -Value "#!/bin/sh
echo fail >&2
exit 1" -NoNewline
        chmod +x $scriptPath
        $env:PATH = "$fakeDir$(if($IsWindows){';'}else{':'})$env:PATH"
        $env:REPOS = "LabVIEW-Community-CI-CD/org-coding-hours-action"
        $result = & $cliExePath 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result | Should -Match "git-hours"
        Remove-Item -Recurse -Force $fakeDir
    }
}