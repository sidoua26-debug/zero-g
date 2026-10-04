[CmdletBinding()]
param (
    [switch]$Apply,
    [switch]$NoRules
)

$ErrorActionPreference = "Stop"
$Date = Get-Date -Format "yyyyMMdd_HHmmss"
$UserHome = $HOME
if (-not $UserHome) { $UserHome = $env:USERPROFILE }

$GeminiDir = Join-Path $UserHome ".gemini"
$ConfigDir = Join-Path $GeminiDir "config"
$ConfigSkills = Join-Path $ConfigDir "skills"
$GlobalSkills = Join-Path $GeminiDir "antigravity\skills"
$BackupsDir = Join-Path $GeminiDir "antigravity\skills-archive\backups"
$RepoDir = $PSScriptRoot

Write-Host "=== zero-g Installer (PowerShell) ==="
if (-not $Apply) {
    Write-Host "MODE: DRY-RUN (Pass -Apply to make changes)"
} else {
    Write-Host "MODE: APPLY (Executing changes with backups)"
}
if ($NoRules) {
    Write-Host "OPTION: -NoRules active (Skipping GEMINI.md)"
}
Write-Host ""

if ($Apply) {
    New-Item -ItemType Directory -Force -Path $ConfigSkills | Out-Null
    New-Item -ItemType Directory -Force -Path $GlobalSkills | Out-Null
}

$Table = [System.Collections.Generic.List[PSCustomObject]]::new()

# 1. Rules
$RulesSrc = Join-Path $RepoDir "rules\GEMINI.md"
$RulesDst = Join-Path $GeminiDir "GEMINI.md"

if ($NoRules) {
    $Table.Add([PSCustomObject]@{ Item = "rules/GEMINI.md"; Status = "skipped"; Notes = "Skipped via -NoRules" })
} elseif (Test-Path $RulesSrc) {
    if (Test-Path $RulesDst) {
        if ($Apply) {
            Copy-Item -Path $RulesDst -Destination "$RulesDst.bak-$Date" -Force
            Copy-Item -Path $RulesSrc -Destination $RulesDst -Force
            $Table.Add([PSCustomObject]@{ Item = "rules/GEMINI.md"; Status = "backed up & installed"; Notes = "Installed to $RulesDst" })
        } else {
            $Table.Add([PSCustomObject]@{ Item = "rules/GEMINI.md"; Status = "would back up & install"; Notes = "Target: $RulesDst" })
        }
    } else {
        if ($Apply) {
            $parentDir = Split-Path -Parent $RulesDst
            if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Force -Path $parentDir | Out-Null }
            Copy-Item -Path $RulesSrc -Destination $RulesDst -Force
            $Table.Add([PSCustomObject]@{ Item = "rules/GEMINI.md"; Status = "installed"; Notes = "Installed to $RulesDst" })
        } else {
            $Table.Add([PSCustomObject]@{ Item = "rules/GEMINI.md"; Status = "would install"; Notes = "Target: $RulesDst" })
        }
    }
}

# 2. Custom Skills
$SkillsSrcDir = Join-Path $RepoDir "skills"
if (Test-Path $SkillsSrcDir) {
    Get-ChildItem -Directory -Path $SkillsSrcDir | ForEach-Object {
        $sName = $_.Name
        $gDst = Join-Path $GlobalSkills $sName
        $cLink = Join-Path $ConfigSkills $sName
        $marker = Join-Path $gDst ".zero-g-managed"

        if ((Test-Path $gDst) -and (-not (Test-Path $marker))) {
            if ($Apply) {
                if (-not (Test-Path $BackupsDir)) { New-Item -ItemType Directory -Force -Path $BackupsDir | Out-Null }
                $bakPath = Join-Path $BackupsDir "$($sName).bak-$Date"
                Move-Item -Path $gDst -Destination $bakPath -Force
                New-Item -ItemType Directory -Force -Path $gDst | Out-Null
                Copy-Item -Recurse -Force -Path "$($_.FullName)\*" -Destination $gDst
                Set-Content -Path $marker -Value "Installed by zero-g"
                try {
                    if (Test-Path $cLink) { Remove-Item -Force -Recurse $cLink }
                    New-Item -ItemType SymbolicLink -Path $cLink -Target $gDst -ErrorAction Stop | Out-Null
                } catch {
                    Copy-Item -Recurse -Force -Path $gDst -Destination $cLink
                }
                $Table.Add([PSCustomObject]@{ Item = "skills/$sName"; Status = "backed up unmanaged & installed"; Notes = "Moved unmanaged to $bakPath" })
            } else {
                $Table.Add([PSCustomObject]@{ Item = "skills/$sName"; Status = "would back up unmanaged & install"; Notes = "Target: $gDst (unmanaged will move to backups)" })
            }
        } else {
            if ($Apply) {
                New-Item -ItemType Directory -Force -Path $gDst | Out-Null
                Copy-Item -Recurse -Force -Path "$($_.FullName)\*" -Destination $gDst
                Set-Content -Path $marker -Value "Installed by zero-g"
                try {
                    if (Test-Path $cLink) { Remove-Item -Force -Recurse $cLink }
                    New-Item -ItemType SymbolicLink -Path $cLink -Target $gDst -ErrorAction Stop | Out-Null
                    $Table.Add([PSCustomObject]@{ Item = "skills/$sName"; Status = "installed"; Notes = "Symlink created in $ConfigSkills" })
                } catch {
                    Copy-Item -Recurse -Force -Path $gDst -Destination $cLink
                    $Table.Add([PSCustomObject]@{ Item = "skills/$sName"; Status = "installed (copied)"; Notes = "Copied (symlink requires Developer Mode)" })
                }
            } else {
                $Table.Add([PSCustomObject]@{ Item = "skills/$sName"; Status = "would install"; Notes = "Target: $gDst" })
            }
        }
    }
}

# 3. Third-party skills lockfile
$LockFile = Join-Path $RepoDir "skills.lock.json"
if (Test-Path $LockFile) {
    $LockData = Get-Content $LockFile | ConvertFrom-Json
    $TempClones = Join-Path $GeminiDir "antigravity\scratch\zero_g_clones"
    if ($Apply) { New-Item -ItemType Directory -Force -Path $TempClones | Out-Null }

    $RepoStatus = @{}

    foreach ($prop in $LockData.skills.PSObject.Properties) {
        $sName = $prop.Name
        $sMeta = $prop.Value
        $targetSkill = Join-Path $ConfigSkills $sName
        $agentsSkill = Join-Path $UserHome ".agents\skills\$sName"

        if ((Test-Path $targetSkill) -or (Test-Path $agentsSkill)) {
            $Table.Add([PSCustomObject]@{ Item = "lock:$sName"; Status = "skipped"; Notes = "Already present in discovery path" })
        } else {
            if ($Apply) {
                if ($RepoStatus.ContainsKey($sMeta.repo) -and ($RepoStatus[$sMeta.repo] -eq "failed")) {
                    $Table.Add([PSCustomObject]@{ Item = "lock:$sName"; Status = "failed"; Notes = "Repository failed previously" })
                    continue
                }

                $slug = $sMeta.repo -replace "https://github.com/", "" -replace "\.git", "" -replace "/", "_"
                $clonePath = Join-Path $TempClones $slug
                if (-not (Test-Path $clonePath)) {
                    git clone --quiet $sMeta.repo $clonePath
                    if ($LASTEXITCODE -ne 0) {
                        $RepoStatus[$sMeta.repo] = "failed"
                        $Table.Add([PSCustomObject]@{ Item = "lock:$sName"; Status = "failed"; Notes = "Clone failed" })
                        continue
                    }
                }

                Push-Location $clonePath
                git checkout --quiet $sMeta.commit
                $chkExit = $LASTEXITCODE
                $currentSha = (git rev-parse HEAD).Trim()
                Pop-Location

                if (($chkExit -ne 0) -or ($currentSha -ne $sMeta.commit)) {
                    $RepoStatus[$sMeta.repo] = "failed"
                    $Table.Add([PSCustomObject]@{ Item = "lock:$sName"; Status = "failed"; Notes = "Checkout failed or SHA mismatch ($currentSha != $($sMeta.commit))" })
                    continue
                }

                $RepoStatus[$sMeta.repo] = "ok"
                $srcFolder = Join-Path $clonePath ($sMeta.path -replace "/", "\")
                if (Test-Path $srcFolder) {
                    $dstFolder = Join-Path $GlobalSkills $sName
                    $dstMarker = Join-Path $dstFolder ".zero-g-managed"
                    if ((Test-Path $dstFolder) -and (-not (Test-Path $dstMarker))) {
                        if (-not (Test-Path $BackupsDir)) { New-Item -ItemType Directory -Force -Path $BackupsDir | Out-Null }
                        $bakPath = Join-Path $BackupsDir "$($sName).bak-$Date"
                        Move-Item -Path $dstFolder -Destination $bakPath -Force
                    }
                    New-Item -ItemType Directory -Force -Path $dstFolder | Out-Null
                    Copy-Item -Recurse -Force -Path "$srcFolder\*" -Destination $dstFolder
                    Set-Content -Path $dstMarker -Value "Installed by zero-g"
                    try {
                        New-Item -ItemType SymbolicLink -Path $targetSkill -Target $dstFolder -ErrorAction Stop | Out-Null
                        $Table.Add([PSCustomObject]@{ Item = "lock:$sName"; Status = "installed"; Notes = "Pinned at $($sMeta.commit.Substring(0,7))" })
                    } catch {
                        Copy-Item -Recurse -Force -Path $dstFolder -Destination $targetSkill
                        $Table.Add([PSCustomObject]@{ Item = "lock:$sName"; Status = "installed (copied)"; Notes = "Pinned at $($sMeta.commit.Substring(0,7)) (copied)" })
                    }
                } else {
                    $Table.Add([PSCustomObject]@{ Item = "lock:$sName"; Status = "failed"; Notes = "Subfolder not in clone" })
                }
            } else {
                $Table.Add([PSCustomObject]@{ Item = "lock:$sName"; Status = "would install"; Notes = "Missing; will pin to $($sMeta.commit.Substring(0,7))" })
            }
        }
    }
}

$Table | Format-Table -AutoSize
if (-not $Apply) {
    Write-Host "Dry-run complete. Run '.\install.ps1 -Apply' to apply changes."
} else {
    Write-Host "Installation complete. Backups preserved with suffix .bak-$Date."
}
