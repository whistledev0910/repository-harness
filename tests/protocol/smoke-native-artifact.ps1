param(
    [Parameter(Mandatory = $true)]
    [string]$Artifact
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$Artifact = (Resolve-Path $Artifact).Path
$Temp = Join-Path ([System.IO.Path]::GetTempPath()) ("harness-protocol-" + [guid]::NewGuid())
$Db = Join-Path $Temp "harness.db"

function Invoke-HarnessJson {
    param(
        [string[]]$Arguments,
        [int]$ExpectedExit = 0
    )
    $stderr = Join-Path $Temp ("stderr-" + [guid]::NewGuid() + ".txt")
    $lines = @(& $Artifact @Arguments 2>$stderr)
    $exit = $LASTEXITCODE
    if ($exit -ne $ExpectedExit) {
        $detail = if (Test-Path $stderr) { Get-Content -Raw $stderr } else { "" }
        $text = $lines -join "`n"
        throw "Harness '$($Arguments -join ' ')' exited $exit, expected $ExpectedExit. stdout=$text stderr=$detail"
    }
    $text = $lines -join "`n"
    try { return $text | ConvertFrom-Json -Depth 100 }
    catch { throw "Harness did not emit one JSON document: $text" }
}

try {
    New-Item -ItemType Directory -Force (Join-Path $Temp "scripts") | Out-Null
    Copy-Item -Recurse (Join-Path $RepoRoot "scripts/schema") (Join-Path $Temp "scripts/schema")
    $env:HARNESS_REPO_ROOT = $Temp
    $env:HARNESS_DB_PATH = $Db

    $contract = Invoke-HarnessJson -Arguments @("query", "contract", "--json")
    if ($contract.result.database_state -ne "missing" -or (Test-Path $Db)) {
        throw "Missing-database discovery mutated state or reported the wrong state"
    }

    & $Artifact init | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "harness init failed" }
    $null = Invoke-HarnessJson -Arguments @("story", "add", "--id", "US-A", "--title", "Alpha", "--lane", "normal", "--verify", "true", "--json")
    $null = Invoke-HarnessJson -Arguments @("story", "add", "--id", "US-B", "--title", "Beta", "--lane", "normal", "--verify", "true", "--json")
    $null = Invoke-HarnessJson -Arguments @("story", "dependency", "add", "--blocker", "US-A", "--blocked", "US-B", "--json")
    $null = Invoke-HarnessJson -Arguments @("story", "hierarchy", "add", "--parent", "US-A", "--child", "US-B", "--json")
    $graph = Invoke-HarnessJson -Arguments @("query", "work-graph", "--json")
    if ($graph.result.revision.Length -ne 64 -or $graph.result.dependencies.Count -ne 1 -or $graph.result.hierarchy.Count -ne 1) {
        throw "Work graph is incomplete or has no stable revision"
    }

    $cas = Invoke-HarnessJson -Arguments @("story", "update", "--id", "US-A", "--status", "implemented", "--expected-status", "planned", "--require-runnable", "--json")
    if ($cas.result.before_status -ne "planned" -or $cas.result.after_status -ne "implemented") {
        throw "CAS result did not report the transition"
    }
    $conflict = Invoke-HarnessJson -Arguments @("story", "hierarchy", "add", "--parent", "US-B", "--child", "US-A", "--json") -ExpectedExit 3
    if ($conflict.error.code -ne "CONFLICT") { throw "Hierarchy cycle was not a stable conflict" }

    $changeset = Join-Path $Temp "protocol-smoke.jsonl"
    '{"base_schema_version":13,"op":"changeset.header","run_id":"protocol_smoke","version":1}' | Set-Content -Encoding utf8NoBOM $changeset
    $status = Invoke-HarnessJson -Arguments @("db", "changeset", "status", $changeset, "--json")
    if ($status.result.applied) { throw "Fresh changeset unexpectedly reported applied" }
    $apply = Invoke-HarnessJson -Arguments @("db", "changeset", "apply", $changeset, "--json")
    if (-not $apply.result.applied -or $apply.result.content_sha256.Length -ne 64) { throw "Changeset apply result is incomplete" }

    $SnapshotDir = Join-Path $Temp "path with spaces"
    New-Item -ItemType Directory -Force $SnapshotDir | Out-Null
    $Snapshot = Join-Path $SnapshotDir "snapshot.db"
    $snapshotResult = Invoke-HarnessJson -Arguments @("db", "snapshot", "--output", $Snapshot, "--json")
    if ($snapshotResult.result.snapshot_file_sha256.Length -ne 64 -or -not (Test-Path $Snapshot)) {
        throw "Snapshot result is incomplete"
    }
    $env:HARNESS_DB_PATH = $Snapshot
    $snapshotContract = Invoke-HarnessJson -Arguments @("query", "contract", "--json")
    if ($snapshotContract.result.database_state -ne "current") { throw "Snapshot is not readable as a current Harness DB" }

    Write-Host "protocol-v1 PowerShell artifact smoke passed"
}
finally {
    Remove-Item Env:HARNESS_REPO_ROOT -ErrorAction SilentlyContinue
    Remove-Item Env:HARNESS_DB_PATH -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $Temp -ErrorAction SilentlyContinue
}
