# squash-all-branches.ps1
# 将指定分支历史压扁为一条 "initial commit" 并强制推送

$ErrorActionPreference = "Stop"

function Write-Info  { Write-Host "[INFO]  $args" -ForegroundColor Cyan }
function Write-Error { Write-Host "[ERROR] $args" -ForegroundColor Red }

# 1. 检查是否在 git 仓库
try {
    git rev-parse --git-dir | Out-Null
} catch {
    Write-Error "Current folder is not a Git repository."
    exit 1
}

# 2. 检查工作区是否干净
git diff --quiet
$workClean = $?
git diff --cached --quiet
$indexClean = $?
if (-not ($workClean -and $indexClean)) {
    Write-Error "Working directory has uncommitted changes."
    exit 1
}

# 3. 拉齐远端
Write-Info "Fetching origin..."
git fetch origin
if ($LASTEXITCODE -ne 0) {
    Write-Error "git fetch failed."
    exit 1
}

# 4. 要处理的分支列表（自己改）
# $BRANCHES = @('main', 'dev', 'feature')
$BRANCHES = @('main')

foreach ($br in $BRANCHES) {
    Write-Host ""
    Write-Info "Processing branch: $br"

    # git checkout $br 2>$null
    # if ($LASTEXITCODE -ne 0) {
    #     Write-Info "Branch $br does not exist, skipped."
    #     continue
    # }

    # 彻底静默切换分支
    $current = git branch --show-current
    if ($current -eq $br) {
        Write-Info "Already on $br, no need to switch."
    } else {
        git checkout $br 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Info "Branch $br does not exist, skipped."
            continue
        }
    }


    git checkout --orphan "new-$br"
    git rm -rf . | Out-Null
    git add .
    git commit -m "initial commit"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Commit failed."
        exit 1
    }

    git branch -f $br
    git checkout $br
    git branch -D "new-$br"

    git push -f origin $br
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Force-push failed for $br."
        exit 1
    }

    Write-Info "Branch $br done."
}

Write-Host ""
# Write-Info "All finished — every branch now has a single 'initial commit'."