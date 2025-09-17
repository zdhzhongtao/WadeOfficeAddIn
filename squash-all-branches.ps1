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
$BRANCHES = @('main', 'dev', 'feature')

foreach ($br in $BRANCHES) {
    Write-Host ""
    Write-Info "Processing branch: $br"

    # ----------  静默判断分支是否存在  ----------
    # 1. 本地是否已存在
    $localExists = git rev-parse --verify --quiet "refs/heads/$br"
    # 2. 远端是否 exists
    $remoteExists = git rev-parse --verify --quiet "refs/remotes/origin/$br"

    if (-not $localExists -and -not $remoteExists) {
        # 两边都没有 → 忽略
        Write-Info "Branch $br does not exist locally or on origin, skipped."
        continue
    }

    # 3. 如果本地没有但远端有，就新建跟踪分支
    if (-not $localExists) {
        git checkout -b $br "origin/$br" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Info "Could not create tracking branch for $br, skipped."
            continue
        }
    }
    else {
        # 本地已有，直接切换（静默）
        git checkout $br 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Info "Could not checkout $br, skipped."
            continue
        }
    }
    # ----------  分支切换完成，继续你的 squash 逻辑  ----------

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