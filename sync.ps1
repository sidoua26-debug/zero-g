[CmdletBinding()]
param (
    [Parameter(Position=0)]
    [ValidateSet("pull", "push")]
    [string]$Action = "pull"
)

$ErrorActionPreference = "Stop"
$RepoDir = $PSScriptRoot
$UserHome = $HOME
if (-not $UserHome) { $UserHome = $env:USERPROFILE }
$GeminiDir = Join-Path $UserHome ".gemini"

if ($Action -eq "pull") {
    Write-Host "=== zero-g Sync: Pull ==="
    Push-Location $RepoDir
    git pull --ff-only
    Pop-Location

    Write-Host "`nRunning installer preview (dry-run):"
    & "$RepoDir\install.ps1"

    $confirm = Read-Host "`nApply incoming zero-g changes now? (y/N)"
    if ($confirm -match "^[Yy]$") {
        & "$RepoDir\install.ps1" -Apply
    } else {
        Write-Host "Aborted. No local files were modified."
    }
} elseif ($Action -eq "push") {
    Write-Host "=== zero-g Sync: Push ==="
    
    Push-Location $RepoDir

    # 0. Commit identity guard
    $userEmail = (git -C $RepoDir config user.email) -as [string]
    if ([string]::IsNullOrWhiteSpace($userEmail) -or ($userEmail -notmatch "@users\.noreply\.github\.com$")) {
        Write-Host "IDENTITY ALERT: git config user.email ('$userEmail') is not a GitHub noreply address." -ForegroundColor Red
        Write-Host "Set the repo-local noreply email before pushing:"
        Write-Host '  git config user.email "<id>+<login>@users.noreply.github.com"'
        Write-Host "  (Find your id via: gh api user --jq .id)"
        Pop-Location
        exit 1
    }

    # Sync live files back into repo
    $liveGemini = Join-Path $GeminiDir "GEMINI.md"
    if (Test-Path $liveGemini) {
        Copy-Item -Path $liveGemini -Destination (Join-Path $RepoDir "rules\GEMINI.md") -Force
    }

    Get-ChildItem -Directory -Path (Join-Path $RepoDir "skills") | ForEach-Object {
        $sName = $_.Name
        $liveSkill = Join-Path $GeminiDir "antigravity\skills\$sName"
        if (Test-Path $liveSkill) {
            Copy-Item -Recurse -Force -Path "$liveSkill\*" -Destination $_.FullName
        }
    }

    # List untracked files
    $untracked = git ls-files --others --exclude-standard
    if ($untracked) {
        Write-Host "Untracked files detected:"
        $untracked | ForEach-Object { Write-Host "  $_" }
        Write-Host ""
    }

    # Stage everything
    git add -A

    Write-Host "Running Public-Readiness Check on staged diff..."
    
    # Pathspec exclusion: scan general files vs sync scripts separately
    $diffGenLines = (git diff --cached -- . ':(exclude)sync.sh' ':(exclude)sync.ps1') -split "`n"
    $diffScriptLines = (git diff --cached -- sync.sh sync.ps1) -split "`n"

    # 1. Secrets check
    $genSecretsPattern = "(?i)(ghp_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9A-Za-z]{10,}|BEGIN [A-Z ]*PRIVATE KEY|(api[_-]?key|token|secret|password)\s*[:=]\s*\S{8,})"
    $secretMatchesGen = $diffGenLines | Where-Object { $_ -match $genSecretsPattern }

    $scriptSecretsPattern = "(?i)(ghp_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9A-Za-z]{10,})"
    $secretMatchesScripts = $diffScriptLines | Where-Object { $_ -match $scriptSecretsPattern }

    if ($secretMatchesGen -or $secretMatchesScripts) {
        Write-Host "SECURITY ALERT: Potential secrets detected in staged diff. Resetting staged changes and aborting push." -ForegroundColor Red
        if ($secretMatchesGen) { $secretMatchesGen | ForEach-Object { Write-Warning $_ } }
        if ($secretMatchesScripts) { $secretMatchesScripts | ForEach-Object { Write-Warning $_ } }
        git reset | Out-Null
        Pop-Location
        exit 1
    }

    # 2. Personal data check
    $localUser = $env:USERNAME
    $ghUser = ""
    try { $ghUser = (gh api user --jq .login 2>$null) } catch {}

    $userTerms = @()
    if ($localUser) { $userTerms += "\b" + [regex]::Escape($localUser) + "\b" }
    if ($ghUser) { $userTerms += "\b" + [regex]::Escape($ghUser) + "\b" }
    $userRegex = "(?i)(" + ($userTerms -join "|") + ")"

    $homeMatchesGen = $diffGenLines | Where-Object { $_ -match "(?i)/home/[a-zA-Z0-9_-]+" }
    $userMatchesGen = if ($userTerms.Count -gt 0) {
        $diffGenLines | Where-Object { $_ -notmatch "https://github\.com/[^/]+/zero-g" -and $_ -match $userRegex }
    } else { @() }
    $emailMatchesGen = $diffGenLines | Where-Object {
        $_ -match "[a-zA-Z0-9_.+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+" -and
        $_ -notmatch "[0-9]+\+[a-zA-Z0-9_-]+@users\.noreply\.github\.com"
    }

    $homeMatchesScripts = $diffScriptLines | Where-Object { $_ -match "(?i)/home/[a-zA-Z0-9_]" }
    $userMatchesScripts = if ($userTerms.Count -gt 0) {
        $diffScriptLines | Where-Object { $_ -notmatch 'user\.email' -and $_ -match $userRegex }
    } else { @() }
    $emailMatchesScripts = $diffScriptLines | Where-Object {
        $_ -match "[a-zA-Z0-9_.+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+" -and
        $_ -notmatch "@users\.noreply\.github\.com"
    }

    if ($homeMatchesGen -or $userMatchesGen -or $emailMatchesGen -or $homeMatchesScripts -or $userMatchesScripts -or $emailMatchesScripts) {
        Write-Host "PRIVACY ALERT: Potential personal data detected in staged diff. Resetting staged changes and aborting push." -ForegroundColor Red
        if ($homeMatchesGen) { $homeMatchesGen | ForEach-Object { Write-Warning $_ } }
        if ($userMatchesGen) { $userMatchesGen | ForEach-Object { Write-Warning $_ } }
        if ($emailMatchesGen) { $emailMatchesGen | ForEach-Object { Write-Warning $_ } }
        if ($homeMatchesScripts) { $homeMatchesScripts | ForEach-Object { Write-Warning $_ } }
        if ($userMatchesScripts) { $userMatchesScripts | ForEach-Object { Write-Warning $_ } }
        if ($emailMatchesScripts) { $emailMatchesScripts | ForEach-Object { Write-Warning $_ } }
        git reset | Out-Null
        Pop-Location
        exit 1
    }

    Write-Host "Public-readiness check PASSED.`n"
    Write-Host "Staged changes summary:"
    git diff --cached --stat
    Write-Host ""

    $confirm = Read-Host "Commit and push these changes to remote? (y/N)"
    if ($confirm -match "^[Yy]$") {
        $msg = Read-Host "Commit message"
        git commit -m $msg
        git push
        Write-Host "Pushed successfully."
    } else {
        Write-Host "Push cancelled. Resetting staged changes."
        git reset | Out-Null
    }
    Pop-Location
}
