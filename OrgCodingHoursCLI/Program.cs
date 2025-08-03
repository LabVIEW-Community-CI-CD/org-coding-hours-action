using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Diagnostics;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.ComponentModel;

class Stats
{
    [JsonPropertyName("hours")]
    public double Hours { get; set; }
    [JsonPropertyName("commits")]
    public int Commits { get; set; }
}

class Program
{
    static int Main()
    {
        try
        {
            EnsureGitHours();

            // Read required environment variables
            string reposEnv = Environment.GetEnvironmentVariable("REPOS") ?? "";
            string windowStart = Environment.GetEnvironmentVariable("WINDOW_START") ?? "";
            string metricsBranch = Environment.GetEnvironmentVariable("METRICS_BRANCH") ?? "";

            // Split the repos list by whitespace/newlines
            string[] repos = reposEnv.Split(new char[] { ' ', '\r', '\n', '\t' }, StringSplitOptions.RemoveEmptyEntries);
            if (repos.Length == 0)
                throw new Exception("REPOS env var must list repositories to process");

            // Prepare a dictionary to hold results for each repo
            var resultsByRepo = new Dictionary<string, Dictionary<string, Stats>>();

            foreach (string repo in repos)
            {
                Console.WriteLine($"Processing {repo}");
                // Run git-hours for this repository and get the per-contributor stats
                var repoStats = RunGitHoursForRepo(repo, windowStart);
                resultsByRepo[repo] = repoStats;
            }

            // Aggregate results across all repositories
            var aggregated = AggregateResults(resultsByRepo.Values);

            // Ensure output directory exists
            Directory.CreateDirectory("reports");
            string date = DateTime.Today.ToString("yyyy-MM-dd");

            // Write individual repo JSON reports
            foreach (var kvp in resultsByRepo)
            {
                string repoName = kvp.Key;
                var data = kvp.Value;
                string slug = Slugify(repoName);
                string filePath = Path.Combine("reports", $"git-hours-{slug}-{date}.json");
                File.WriteAllText(filePath, JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true }));
            }

            // Write aggregated JSON report
            string aggregatedPath = Path.Combine("reports", $"git-hours-aggregated-{date}.json");
            File.WriteAllText(aggregatedPath, JsonSerializer.Serialize(aggregated, new JsonSerializerOptions { WriteIndented = true }));

            // Determine which file to output as the aggregated report (single repo vs multiple)
            string repoSlug;
            string outputPath;
            if (repos.Length == 1)
            {
                // If only one repo, use that repo's report as the output
                repoSlug = Slugify(repos[0]);
                outputPath = Path.Combine("reports", $"git-hours-{repoSlug}-{date}.json");
            }
            else
            {
                // Multiple repos: use the aggregated report
                var slugs = new List<string>();
                foreach (string repo in repos) slugs.Add(Slugify(repo));
                repoSlug = string.Join("-", slugs);
                outputPath = aggregatedPath;
            }

            // Set GitHub Actions outputs (if GITHUB_OUTPUT is set)
            string githubOutput = Environment.GetEnvironmentVariable("GITHUB_OUTPUT");
            if (!string.IsNullOrEmpty(githubOutput))
            {
                using var writer = File.AppendText(githubOutput);
                writer.WriteLine($"aggregated_report={outputPath}");
                writer.WriteLine($"repo_slug={repoSlug}");
            }

            // Print aggregated JSON to console for reference
            Console.WriteLine(JsonSerializer.Serialize(aggregated, new JsonSerializerOptions { WriteIndented = true }));

            // If a metrics branch is specified, commit the reports to that branch
            if (!string.IsNullOrEmpty(metricsBranch))
            {
                Console.WriteLine($"Pushing reports to branch '{metricsBranch}'...");
                CommitToBranch(metricsBranch, "reports");
            }

            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"ERROR: {ex.Message}");
            return 1;
        }
    }

    // Clone the repo, run git-hours, and return the parsed JSON results
    static Dictionary<string, Stats> RunGitHoursForRepo(string repo, string since)
    {
        // Determine clone URL, using GITHUB_TOKEN for private repos if available
        string token = Environment.GetEnvironmentVariable("GITHUB_TOKEN") ?? "";
        string url = $"https://github.com/{repo}.git";
        if (!string.IsNullOrEmpty(token))
        {
            url = $"https://x-access-token:{token}@github.com/{repo}.git";
        }

        // Create a temporary directory for cloning
        string cloneDir = Path.Combine(Path.GetTempPath(), "repo_" + Guid.NewGuid());
        Directory.CreateDirectory(cloneDir);
        try
        {
            // Clone the repository (quietly, to fetch full history without verbose output)
            RunCommand("git", $"clone --quiet {url} \"{cloneDir}\"");

            // Build git-hours command (include -since if a start date is provided)
            string args = "";
            if (!string.IsNullOrEmpty(since))
                args = $"-since \"{since}\"";
            var psi = new ProcessStartInfo("git-hours", args)
            {
                WorkingDirectory = cloneDir,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false
            };
            using var proc = Process.Start(psi);
            string output = proc.StandardOutput.ReadToEnd();
            proc.WaitForExit();
            string err = proc.StandardError.ReadToEnd();
            if (proc.ExitCode != 0)
            {
                throw new Exception($"git-hours failed for {repo}: {err}".Trim());
            }

            // Parse the git-hours JSON output into a dictionary
            var repoData = JsonSerializer.Deserialize<Dictionary<string, Stats>>(output);
            return repoData ?? new Dictionary<string, Stats>();
        }
        finally
        {
            // Clean up: remove the temporary clone directory
            try { Directory.Delete(cloneDir, true); } catch { /* ignore cleanup errors */ }
        }
    }

    // Aggregate multiple per-repo results into a combined result
    static Dictionary<string, Stats> AggregateResults(IEnumerable<Dictionary<string, Stats>> resultsList)
    {
        var agg = new Dictionary<string, Stats>();
        // Initialize total entry
        agg["total"] = new Stats { Hours = 0, Commits = 0 };

        foreach (var repoData in resultsList)
        {
            foreach (var entry in repoData)
            {
                string key = entry.Key;
                if (key == "total") continue; // skip per-repo totals
                Stats stats = entry.Value;
                if (!agg.ContainsKey(key))
                {
                    agg[key] = new Stats { Hours = 0, Commits = 0 };
                }
                agg[key].Hours += stats.Hours;
                agg[key].Commits += stats.Commits;
                // Update aggregate total
                agg["total"].Hours += stats.Hours;
                agg["total"].Commits += stats.Commits;
            }
        }
        return agg;
    }

    // Push the contents of sourcePath (file or directory) to the specified branch of the current repo
    static void CommitToBranch(string branchName, string sourcePath)
    {
        string token = Environment.GetEnvironmentVariable("GITHUB_TOKEN") ?? "";
        string repoSlug = Environment.GetEnvironmentVariable("GITHUB_REPOSITORY") ?? "";
        if (string.IsNullOrEmpty(token) || string.IsNullOrEmpty(repoSlug))
            throw new Exception("GITHUB_TOKEN or GITHUB_REPOSITORY not set; cannot push to branch");

        string repoUrl = $"https://x-access-token:{token}@github.com/{repoSlug}.git";
        string cloneDir = Path.Combine(Path.GetTempPath(), "push_" + Guid.NewGuid());
        Directory.CreateDirectory(cloneDir);

        try
        {
            // 1. Clone the repository (shallow clone of default branch)
            RunCommand("git", $"clone --depth 1 \"{repoUrl}\" \"{cloneDir}\"");

            // 2. Fetch the target branch if it exists (ignore errors if branch doesn’t exist yet)
            var fetchProc = Process.Start(new ProcessStartInfo("git", $"fetch origin {branchName}")
            {
                WorkingDirectory = cloneDir,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false
            });
            fetchProc?.WaitForExit();

            // 3. Check out the target branch (create if it doesn’t exist)
            bool branchExisted = true;
            var checkoutProc = Process.Start(new ProcessStartInfo("git", $"checkout -B {branchName} origin/{branchName}")
            {
                WorkingDirectory = cloneDir,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false
            });
            checkoutProc?.WaitForExit();
            if (checkoutProc == null || checkoutProc.ExitCode != 0)
            {
                // Branch does not exist on remote: create an orphan branch
                RunCommand("git", $"checkout --orphan {branchName}", cloneDir);
                branchExisted = false;
            }

            // 4. If new branch, remove all existing files (start fresh)
            if (!branchExisted)
            {
                foreach (string entry in Directory.GetFileSystemEntries(cloneDir))
                {
                    string name = Path.GetFileName(entry);
                    if (name == ".git") continue;
                    if (Directory.Exists(entry))
                        Directory.Delete(entry, true);
                    else
                        File.Delete(entry);
                }
            }

            // 5. Copy new content into the working tree
            if (Directory.Exists(sourcePath))
            {
                // Copy all files under sourcePath into cloneDir
                foreach (string srcFile in Directory.GetFiles(sourcePath, "*", SearchOption.AllDirectories))
                {
                    string relativePath = Path.GetRelativePath(sourcePath, srcFile);
                    string destFile = Path.Combine(cloneDir, relativePath);
                    Directory.CreateDirectory(Path.GetDirectoryName(destFile)!);
                    File.Copy(srcFile, destFile, overwrite: true);
                }
            }
            else if (File.Exists(sourcePath))
            {
                string fileName = Path.GetFileName(sourcePath);
                File.Copy(sourcePath, Path.Combine(cloneDir, fileName), overwrite: true);
            }
            else
            {
                throw new Exception($"Source path '{sourcePath}' not found");
            }

            // 6. Commit and push changes
            RunCommand("git", "add .", cloneDir);
            RunCommand("git", "config user.name github-actions", cloneDir);
            RunCommand("git", "config user.email actions@users.noreply.github.com", cloneDir);

            // Check if there are new changes to commit
            var diffProc = Process.Start(new ProcessStartInfo("git", "diff --cached --quiet") { WorkingDirectory = cloneDir });
            diffProc?.WaitForExit();
            if (diffProc != null && diffProc.ExitCode == 0)
            {
                Console.WriteLine($"No changes to commit for branch '{branchName}'");
            }
            else
            {
                RunCommand("git", $"commit -m \"Update {branchName} data\"", cloneDir);
                RunCommand("git", $"push -u origin {branchName}", cloneDir);
            }
        }
        finally
        {
            // Clean up the temporary repo clone
            try { Directory.Delete(cloneDir, true); } catch { /* ignore */ }
        }
    }

    // Ensure the git-hours command is available in PATH
    static void EnsureGitHours()
    {
        string pathEnv = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
        string? repoDir = AppContext.BaseDirectory;
        string binDir = Path.Combine(repoDir, "bin");
        if (Directory.Exists(binDir) && Array.IndexOf(pathEnv.Split(Path.PathSeparator), binDir) < 0)
        {
            pathEnv = binDir + Path.PathSeparator + pathEnv;
            Environment.SetEnvironmentVariable("PATH", pathEnv);
        }

        if (!CommandExists("git-hours"))
            throw new Exception("git-hours CLI not found in PATH");
    }

    // Determine whether the given command exists on the current system
    static bool CommandExists(string command)
    {
        try
        {
            var psi = new ProcessStartInfo(command, "--help")
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false
            };
            using var proc = Process.Start(psi);
            proc?.WaitForExit();
            return proc != null && proc.ExitCode == 0;
        }
        catch (Win32Exception) when (OperatingSystem.IsWindows())
        {
            try
            {
                var psi = new ProcessStartInfo(command + ".exe", "--help")
                {
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false
                };
                using var proc = Process.Start(psi);
                proc?.WaitForExit();
                return proc != null && proc.ExitCode == 0;
            }
            catch
            {
                return false;
            }
        }
        catch
        {
            return false;
        }
    }

    // Replace unsafe characters in repo names (for file paths and slug)
    static string Slugify(string text)
    {
        string slug = text.Replace('/', '_').Replace(' ', '_');
        return Regex.Replace(slug, @"[^0-9A-Za-z._-]+", "_");
    }

    // Run a shell command and throw if it exits with an error
    static void RunCommand(string fileName, string arguments, string? workingDir = null)
    {
        var psi = new ProcessStartInfo(fileName, arguments)
        {
            WorkingDirectory = workingDir ?? Environment.CurrentDirectory,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false
        };
        using var proc = Process.Start(psi);
        proc.WaitForExit();
        string stderr = proc.StandardError.ReadToEnd();
        if (proc.ExitCode != 0)
        {
            throw new Exception($"Command `{fileName} {arguments}` failed (exit code {proc.ExitCode}): {stderr}".Trim());
        }
    }
}