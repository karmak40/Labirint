<#
Builds the signed Android App Bundle for Google Play: build/android/Labirint.aab.

  .\tools\build_release.ps1 -Version 0.2 -Code 2

  -Version   the version players see (version/name); optional
  -Code      the version code, a whole number that must grow with every upload
             to Play (version/code); optional, but Play refuses a code it has
             already seen
  -Godot     the Godot console executable, if not at the usual place

The upload key is never kept in the project. The script takes it from the
environment, the same variables Godot itself reads:

  GODOT_ANDROID_KEYSTORE_RELEASE_PATH      the .keystore file
                                           (default: ~\keys\labirint-release.keystore)
  GODOT_ANDROID_KEYSTORE_RELEASE_USER      the key alias (default: labirint)
  GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD  asked for here if not set

Make the key once with keytool (see docs/android_release.md).
#>
param(
    [string]$Version = "",
    [int]$Code = 0,
    [string]$Godot = $env:GODOT
)

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = "E:\Apps\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe" }
if (-not (Test-Path $Godot)) { Write-Host "Godot not found at '$Godot'. Pass -Godot or set GODOT." -ForegroundColor Red; exit 2 }

# the key
if (-not $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH) {
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = Join-Path $HOME "keys\labirint-release.keystore"
}
if (-not (Test-Path $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH)) {
    Write-Host "No keystore at '$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH'. Make one first (docs/android_release.md)." -ForegroundColor Red
    exit 2
}
if (-not $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER) { $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "labirint" }
$askedPassword = $false
if (-not $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD) {
    $secure = Read-Host "Keystore password" -AsSecureString
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    $askedPassword = $true
}

# the version, written into the "Android Google Play" preset
$presets = Join-Path $project "export_presets.cfg"
$text = [IO.File]::ReadAllText($presets)
$start = $text.IndexOf('name="Android Google Play"')
if ($start -lt 0) { Write-Host "No 'Android Google Play' preset in export_presets.cfg." -ForegroundColor Red; exit 2 }
$head = $text.Substring(0, $start)
$tail = $text.Substring($start)
if ($Code -gt 0) { $tail = [regex]::Replace($tail, '(?m)^version/code=\d+', "version/code=$Code", 1) }
if ($Version) { $tail = [regex]::Replace($tail, '(?m)^version/name=".*"', "version/name=`"$Version`"", 1) }
[IO.File]::WriteAllText($presets, $head + $tail)
$shownCode = [regex]::Match($tail, '(?m)^version/code=(\d+)').Groups[1].Value
$shownName = [regex]::Match($tail, '(?m)^version/name="(.*)"').Groups[1].Value
Write-Host "Building Labirint $shownName (code $shownCode)..."

$out = Join-Path $project "build\android"
New-Item -ItemType Directory -Force $out | Out-Null
$aab = Join-Path $out "Labirint.aab"
Remove-Item $aab -ErrorAction SilentlyContinue
$log = Join-Path $out "export.log"
try {
    # Output goes to a file and only Godot itself is waited for: the Gradle
    # daemon it starts inherits its pipes and would hold a pipeline open.
    $env:GRADLE_OPTS = "-Dorg.gradle.daemon=false"
    $process = Start-Process -FilePath $Godot -NoNewWindow -PassThru `
        -ArgumentList @("--headless", "--path", "`"$project`"", "--install-android-build-template",
            "--export-release", "`"Android Google Play`"", "`"$aab`"") `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    $null = $process.Handle
    $process.WaitForExit()
    Get-Content $log, "$log.err" -ErrorAction SilentlyContinue |
        Where-Object { $_ -match "ERROR|error:|FAILED|BUILD" -and $_ -notmatch "EditorSettings not instantiated" } |
        ForEach-Object { Write-Host "  $_" }
} finally {
    if ($askedPassword) { Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD }
    # Gradle leaves a daemon behind, which would hold this console open
    $gradlew = Join-Path $project "android\build\gradlew.bat"
    if (Test-Path $gradlew) {
        if (-not $env:JAVA_HOME) { $env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr" }
        & $gradlew --stop 2>&1 | Out-Null
    }
}

if (-not (Test-Path $aab)) { Write-Host "No bundle was made; run the export in the editor to see why." -ForegroundColor Red; exit 1 }
$size = (Get-Item $aab).Length / 1MB
Write-Host ("Done: {0} ({1:N1} MB). Upload it in Play Console." -f $aab, $size) -ForegroundColor Green
