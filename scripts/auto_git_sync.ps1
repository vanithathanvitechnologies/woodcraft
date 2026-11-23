param(
    [int]$DebounceSeconds = 8,
    [switch]$Once
)

$ErrorActionPreference = 'Continue'
$RepoPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$LogFile = Join-Path $RepoPath 'auto_git_sync.log'
$IgnoreRegex = '(^|\\)(\.git|node_modules|build|\.dart_tool|\.gradle|\.idea|dist|dist-ssr)(\\|$)|(\.log|\.tmp|\.swp|~)$'

function Write-SyncLog {
    param([string]$Message)
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$stamp] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

function Invoke-GitSync {
    Push-Location $RepoPath
    try {
        # Wait briefly if another git process holds index.lock
        $lockFile = Join-Path $RepoPath '.git\index.lock'
        $waited = 0
        while ((Test-Path $lockFile) -and ($waited -lt 10)) {
            Start-Sleep -Seconds 1
            $waited++
        }

        $status = @(git status --porcelain 2>&1)
        if (-not $status -or $status.Count -eq 0) {
            return
        }

        $changedNames = @()
        foreach ($row in $status) {
            $trimmed = ($row -as [string]).Trim()
            if ($trimmed.Length -gt 3) {
                $pathPart = $trimmed.Substring(2).Trim().Trim('"')
                $changedNames += Split-Path -Leaf $pathPart
            }
        }
        $uniqueNames = @($changedNames | Select-Object -Unique)
        $summary = ($uniqueNames | Select-Object -First 3) -join ', '
        if ($uniqueNames.Count -gt 3) {
            $summary = "$summary (+$($uniqueNames.Count - 3) more)"
        }
        if (-not $summary) { $summary = 'workspace changes' }

        $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $commitMsg = "Auto-sync $stamp - $summary"

        git add -A | Out-Null
        $commitOut = git commit -m $commitMsg 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-SyncLog "Commit skipped or failed: $commitOut"
            return
        }

        $pushOut = git push origin main 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-SyncLog "Pushed to origin/main: $commitMsg"
        } else {
            Write-SyncLog "Push failed: $pushOut"
        }
    } finally {
        Pop-Location
    }
}

if ($Once) {
    Invoke-GitSync
    exit 0
}

Write-SyncLog "Auto Git Sync started on $RepoPath (debounce: ${DebounceSeconds}s). Press Ctrl+C to stop."

# Sync any existing pending changes on startup
Invoke-GitSync

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $RepoPath
$watcher.Filter = '*.*'
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
$watcher.EnableRaisingEvents = $true

$sourceIds = @('WoodCraftGitChanged', 'WoodCraftGitCreated', 'WoodCraftGitDeleted', 'WoodCraftGitRenamed')
Register-ObjectEvent -InputObject $watcher -EventName Changed -SourceIdentifier $sourceIds[0] | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier $sourceIds[1] | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Deleted -SourceIdentifier $sourceIds[2] | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Renamed -SourceIdentifier $sourceIds[3] | Out-Null

$pending = $false
$lastChange = Get-Date

try {
    while ($true) {
        $evt = Wait-Event -Timeout 1
        if ($evt) {
            $fullPath = $evt.SourceEventArgs.FullPath
            Remove-Event -EventIdentifier $evt.EventIdentifier -ErrorAction SilentlyContinue
            if ($fullPath -and ($fullPath -notmatch $IgnoreRegex)) {
                $pending = $true
                $lastChange = Get-Date
            }
        }

        if ($pending -and (((Get-Date) - $lastChange).TotalSeconds -ge $DebounceSeconds)) {
            $pending = $false
            Invoke-GitSync
        }
    }
} finally {
    foreach ($id in $sourceIds) {
        Unregister-Event -SourceIdentifier $id -ErrorAction SilentlyContinue
    }
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
    Write-SyncLog "Auto Git Sync stopped."
}
