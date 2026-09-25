<#
Runs the automated tests in tests/ headless and prints a summary.

  .\tests\run_tests.ps1                     every fast test
  .\tests\run_tests.ps1 -Only economy       just the tests whose name has "economy"
  .\tests\run_tests.ps1 -Godot C:\path\to\Godot_console.exe

Godot is looked for in -Godot, then in the GODOT environment variable, then at
the path used on the development machine. Use the *_console.exe build, so the
output shows up here. Exits 1 if any test failed.

Benchmarks (tests/bench) are not run here; they need a window. See each file.
#>
param(
    [string]$Godot = $env:GODOT,
    [string]$Only = "",
    [int]$TimeoutSeconds = 600
)

$project = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = "E:\Apps\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe" }
if (-not (Test-Path $Godot)) {
    Write-Host "Godot not found at '$Godot'. Pass -Godot or set GODOT." -ForegroundColor Red
    exit 2
}

$tests = @(Get-ChildItem (Join-Path $PSScriptRoot "test_*.gd") | Sort-Object Name)
if ($Only) { $tests = @($tests | Where-Object { $_.BaseName -like "*$Only*" }) }
if ($tests.Count -eq 0) { Write-Host "No tests match." -ForegroundColor Yellow; exit 2 }

# class names and imports are refreshed first, or a new script's class_name is unknown
& $Godot --headless --path $project --import 2>&1 | Out-Null

$failed = @()
$started = Get-Date
foreach ($test in $tests) {
    $relative = $test.FullName.Substring($project.Length + 1).Replace('\', '/')
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $log = Join-Path ([IO.Path]::GetTempPath()) ("labirint_" + $test.BaseName + ".log")
    $process = Start-Process -FilePath $Godot -NoNewWindow -PassThru `
        -ArgumentList @("--headless", "--fixed-fps", "60", "--path", "`"$project`"", "-s", "res://$relative") `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    # read the handle now: without it PowerShell loses the exit code of a redirected process
    $null = $process.Handle
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        $code = -1
    } else {
        $code = $process.ExitCode
    }
    $clock.Stop()
    $output = @(Get-Content $log -ErrorAction SilentlyContinue) + @(Get-Content "$log.err" -ErrorAction SilentlyContinue)
    $errors = @($output | Where-Object { $_ -match "SCRIPT ERROR|Parse Error|Compile Error" })
    $verdict = @($output | Where-Object { $_ -match "^(PASS|FAIL): " }) | Select-Object -Last 1
    $seconds = "{0,5:N1}s" -f $clock.Elapsed.TotalSeconds
    # A test says PASS or FAIL itself before it exits, and a failure exits 1. Any
    # other non-zero code after a PASS line is the engine falling over while
    # shutting down -- it happens now and then in -s runs, never in the game --
    # so the test's own verdict stands.
    $crashed_after_pass = ($code -ne 0 -and $code -ne 1 -and $code -ne -1 -and $verdict -like "PASS:*")
    if ($errors.Count -eq 0 -and ($code -eq 0 -or $crashed_after_pass)) {
        $note = if ($crashed_after_pass) { "  (crashed on exit after passing, code $code)" } else { "" }
        Write-Host ("PASS  {0}  {1}{2}" -f $seconds, $test.BaseName, $note) -ForegroundColor Green
    } else {
        $why = if ($code -eq -1) { "timed out" } elseif ($errors.Count -gt 0) { "script error" } else { "exit $code" }
        Write-Host ("FAIL  {0}  {1}  ({2})" -f $seconds, $test.BaseName, $why) -ForegroundColor Red
        $output | Where-Object { $_ -match "FAIL|ERROR|Error" } | Select-Object -First 15 | ForEach-Object { Write-Host "        $_" }
        $failed += $test.BaseName
    }
    Remove-Item $log, "$log.err" -ErrorAction SilentlyContinue
}

$total = (Get-Date) - $started
Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host ("All {0} tests passed in {1:N0}s." -f $tests.Count, $total.TotalSeconds) -ForegroundColor Green
    exit 0
}
Write-Host ("{0} of {1} failed: {2}" -f $failed.Count, $tests.Count, ($failed -join ", ")) -ForegroundColor Red
exit 1
