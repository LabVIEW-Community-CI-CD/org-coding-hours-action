using System;
using System.Collections.Generic;
using System.IO;
using Xunit;

public class ProgramTests
{
    [Fact]
    public void AggregateResults_SumsContributors()
    {
        var repo1 = new Dictionary<string, Stats>{
            ["alice"] = new Stats{Hours=1, Commits=2},
            ["total"] = new Stats{Hours=1, Commits=2}
        };
        var repo2 = new Dictionary<string, Stats>{
            ["alice"] = new Stats{Hours=3, Commits=4},
            ["bob"] = new Stats{Hours=2, Commits=1},
            ["total"] = new Stats{Hours=5, Commits=5}
        };
        var agg = Program.AggregateResults(new[]{repo1, repo2});
        Assert.Equal(3, agg.Count);
        Assert.Equal(4, agg["alice"].Hours);
        Assert.Equal(6, agg["alice"].Commits);
        Assert.Equal(2, agg["bob"].Hours);
        Assert.Equal(1, agg["bob"].Commits);
        Assert.Equal(6, agg["total"].Hours);
        Assert.Equal(7, agg["total"].Commits);
    }

    [Theory]
    [InlineData("octocat/Hello-World", "octocat_Hello-World")]
    [InlineData("Repo With Spaces", "Repo_With_Spaces")]
    [InlineData("name%with$chars", "name_with_chars")]
    public void Slugify_ReplacesSpecialCharacters(string input, string expected)
    {
        Assert.Equal(expected, Program.Slugify(input));
    }

    [Fact]
    public void EnsureGitHours_ThrowsWhenGoMissing()
    {
        var originalExists = Program.CommandExistsFunc;
        var originalRun = Program.RunCommandAction;
        Program.CommandExistsFunc = _ => false;
        Program.RunCommandAction = (_,__,___) => { };
        try
        {
            Assert.ThrowsAny<Exception>(() =>
            {
                var mi = typeof(Program).GetMethod("EnsureGitHours", System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Static);
                mi!.Invoke(null, null);
            });
        }
        finally
        {
            Program.CommandExistsFunc = originalExists;
            Program.RunCommandAction = originalRun;
        }
    }

    [Fact]
    public void EnsureGitHours_BuildsSpecifiedVersion()
    {
        var calls = new List<string>();
        var originalExists = Program.CommandExistsFunc;
        var originalRun = Program.RunCommandAction;
        var builtFlag = false;
        Program.CommandExistsFunc = cmd =>
        {
            if (cmd == "git-hours") return builtFlag;
            return true;
        };
        Program.RunCommandAction = (file,args,workDir) =>
        {
            calls.Add($"{file} {args}");
            if (file=="git" && args.StartsWith("clone"))
            {
                var dir = args.Split(' ')[^1].Trim('"');
                Directory.CreateDirectory(dir);
            }
            if (file=="go")
            {
                var built = Path.Combine(workDir!, "git-hours");
                File.WriteAllText(built, string.Empty);
                builtFlag = true;
            }
        };
        Environment.SetEnvironmentVariable("GIT_HOURS_VERSION", "v9.9.9");
        try
        {
            var mi = typeof(Program).GetMethod("EnsureGitHours", System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Static);
            mi!.Invoke(null, null);
            Assert.Contains(calls, c => c.Contains("git clone"));
            Assert.Contains(calls, c => c.Contains("git checkout v9.9.9"));
            Assert.Contains(calls, c => c.StartsWith("go build"));
        }
        finally
        {
            Program.CommandExistsFunc = originalExists;
            Program.RunCommandAction = originalRun;
            Environment.SetEnvironmentVariable("GIT_HOURS_VERSION", null);
        }
    }

    [Fact]
    public void CommitToBranch_CreatesOrphanWhenBranchMissing()
    {
        var cmds = new List<string>();
        var originalRun = Program.RunCommandAction;
        Program.RunCommandAction = (file,args,workDir) =>
        {
            cmds.Add($"{file} {args}");
            if (file=="git" && args.StartsWith("clone"))
            {
                var dir = args.Split(' ')[^1].Trim('"');
                Directory.CreateDirectory(dir);
            }
            else if (file=="git" && args.StartsWith("checkout -B"))
            {
                throw new Exception("fail");
            }
            else if (file=="git" && args.StartsWith("diff"))
            {
                throw new Exception("changes");
            }
        };
        Environment.SetEnvironmentVariable("GITHUB_TOKEN", "t");
        Environment.SetEnvironmentVariable("GITHUB_REPOSITORY", "owner/repo");
        var src = Directory.CreateDirectory(Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString()));
        File.WriteAllText(Path.Combine(src.FullName, "a.txt"), "x");
        try
        {
            var mi = typeof(Program).GetMethod("CommitToBranch", System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Static);
            mi!.Invoke(null, new object[]{"test", src.FullName});
            Assert.Contains(cmds, c => c.Contains("checkout --orphan"));
            Assert.Contains(cmds, c => c.Contains("commit -m"));
            Assert.Contains(cmds, c => c.Contains("push -u"));
        }
        finally
        {
            Program.RunCommandAction = originalRun;
            Environment.SetEnvironmentVariable("GITHUB_TOKEN", null);
            Environment.SetEnvironmentVariable("GITHUB_REPOSITORY", null);
            Directory.Delete(src.FullName, true);
        }
    }

    [Fact]
    public void CommitToBranch_SkipsPushWhenNoChanges()
    {
        var cmds = new List<string>();
        var originalRun = Program.RunCommandAction;
        Program.RunCommandAction = (file,args,workDir) =>
        {
            cmds.Add($"{file} {args}");
            if (file=="git" && args.StartsWith("clone"))
            {
                var dir = args.Split(' ')[^1].Trim('"');
                Directory.CreateDirectory(dir);
            }
        };
        Environment.SetEnvironmentVariable("GITHUB_TOKEN", "t");
        Environment.SetEnvironmentVariable("GITHUB_REPOSITORY", "owner/repo");
        var src = Directory.CreateDirectory(Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString()));
        File.WriteAllText(Path.Combine(src.FullName, "a.txt"), "x");
        try
        {
            var mi = typeof(Program).GetMethod("CommitToBranch", System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Static);
            mi!.Invoke(null, new object[]{"test", src.FullName});
            Assert.DoesNotContain(cmds, c => c.Contains("commit -m"));
            Assert.DoesNotContain(cmds, c => c.Contains("push -u"));
        }
        finally
        {
            Program.RunCommandAction = originalRun;
            Environment.SetEnvironmentVariable("GITHUB_TOKEN", null);
            Environment.SetEnvironmentVariable("GITHUB_REPOSITORY", null);
            Directory.Delete(src.FullName, true);
        }
    }
}

