#Requires -Version 7
<#
.SYNOPSIS
    探测 Windows 上 Codex / Claude Code 的数据路径和文件格式。
.DESCRIPTION
    不读取敏感线程正文，只列出路径、检查文件存在、提取 JSONL 字段名、检查 UTF-8 BOM。
    输出到 findings.yaml。
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "$PSScriptRoot\findings.yaml"
)

$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

function Expand-EnvPath {
    param([string]$Path)
    return [Environment]::ExpandEnvironmentVariables($Path)
}

function Test-AnyFile {
    param([string]$Pattern)
    $items = Get-ChildItem -Path (Split-Path $Pattern -Parent) -Filter (Split-Path $Pattern -Leaf) -Recurse -File
    return ($items.Count -gt 0)
}

function Get-FirstFile {
    param([string]$Pattern)
    $items = Get-ChildItem -Path (Split-Path $Pattern -Parent) -Filter (Split-Path $Pattern -Leaf) -Recurse -File | Select-Object -First 1
    return $items
}

function Test-HasBOM {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath)) { return $null }
    $bytes = [System.IO.File]::ReadAllBytes($FilePath) | Select-Object -First 3
    if ($bytes.Count -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return $true
    }
    return $false
}

function Get-JsonlFieldNames {
    param([string]$FilePath, [int]$SampleLines = 5)
    if (-not (Test-Path $FilePath)) { return @() }
    $fields = [System.Collections.Generic.HashSet[string]]::new()
    $count = 0
    foreach ($line in [System.IO.File]::ReadLines($FilePath)) {
        if ($count -ge $SampleLines) { break }
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $obj = $line | ConvertFrom-Json -Depth 3
            $obj.PSObject.Properties.Name | ForEach-Object { $fields.Add($_) | Out-Null }
            # 检查 message 字段子属性
            if ($obj.message) {
                $obj.message.PSObject.Properties.Name | ForEach-Object { $fields.Add("message.$_") | Out-Null }
            }
        } catch {}
        $count++
    }
    return $fields | Sort-Object
}

function Test-SqliteSchema {
    param([string]$DbPath)
    if (-not (Test-Path $DbPath)) { return $null }
    $sqlite3 = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if (-not $sqlite3) { return "sqlite3 not found" }
    $schema = & sqlite3 $DbPath ".schema" 2>$null
    $hasThreads = $schema -match "CREATE TABLE threads"
    $hasRolloutPath = $schema -match "rollout_path"
    $hasThreadSpawnEdges = $schema -match "CREATE TABLE thread_spawn_edges"
    return @{
        has_threads_table = $hasThreads
        has_rollout_path = $hasRolloutPath
        has_thread_spawn_edges = $hasThreadSpawnEdges
        notes = if ($hasThreads -and $hasRolloutPath -and $hasThreadSpawnEdges) { "schema matches macOS reference" } else { "schema differs from macOS reference" }
    }
}

function Test-AppServer {
    $codex = Get-Command codex -ErrorAction SilentlyContinue
    if (-not $codex) { return @{ available = $false; notes = "codex CLI not found in PATH" } }
    $help = & codex app-server --help 2>&1
    return @{
        available = ($LASTEXITCODE -eq 0)
        notes = ($help -join "; ").Substring(0, [Math]::Min(200, ($help -join "; ").Length))
    }
}

# ==================== Codex 探测 ====================

$codexRoots = @(
    "%USERPROFILE%\.codex"
    "%LOCALAPPDATA%\Codex"
    "%APPDATA%\Codex"
)

$codexDataRoot = $null
foreach ($root in $codexRoots) {
    $expanded = Expand-EnvPath $root
    if (Test-Path $expanded) {
        $codexDataRoot = $expanded
        break
    }
}

$state5Path = $null
if ($codexDataRoot) {
    $candidates = @(
        "$codexDataRoot\state_5.sqlite"
        "$codexDataRoot\sqlite\state_5.sqlite"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $state5Path = $c; break }
    }
}

$codexJsonlPattern = $null
if ($codexDataRoot) {
    $patterns = @(
        "$codexDataRoot\sessions\**\rollout-*.jsonl"
        "$codexDataRoot\sessions\**\*.jsonl"
        "$codexDataRoot\archived_sessions\*.jsonl"
    )
    foreach ($p in $patterns) {
        if (Test-AnyFile $p) { $codexJsonlPattern = $p; break }
    }
}

$codexJsonlSample = if ($codexJsonlPattern) { Get-FirstFile $codexJsonlPattern } else { $null }
$codexJsonlFields = if ($codexJsonlSample) { Get-JsonlFieldNames $codexJsonlSample.FullName } else { @() }
$codexJsonlHasBOM = if ($codexJsonlSample) { Test-HasBOM $codexJsonlSample.FullName } else { $null }

$automationPattern = if ($codexDataRoot) { "$codexDataRoot\automations\**\automation.toml" } else { $null }
$automationExists = if ($automationPattern) { Test-AnyFile $automationPattern } else { $false }

# ==================== Claude Code 探测 ====================

$claudeRoots = @(
    "%USERPROFILE%\.claude"
    "%APPDATA%\Claude"
    "%LOCALAPPDATA%\Claude"
)

$claudeDataRoot = $null
foreach ($root in $claudeRoots) {
    $expanded = Expand-EnvPath $root
    if (Test-Path $expanded) {
        $claudeDataRoot = $expanded
        break
    }
}

$claudeTranscriptPattern = $null
if ($claudeDataRoot) {
    $patterns = @(
        "$claudeDataRoot\projects\**\*.jsonl"
    )
    foreach ($p in $patterns) {
        if (Test-AnyFile $p) { $claudeTranscriptPattern = $p; break }
    }
}

$claudeTranscriptSample = if ($claudeTranscriptPattern) { Get-FirstFile $claudeTranscriptPattern } else { $null }
$claudeTranscriptFields = if ($claudeTranscriptSample) { Get-JsonlFieldNames $claudeTranscriptSample.FullName } else { @() }
$claudeTranscriptHasBOM = if ($claudeTranscriptSample) { Test-HasBOM $claudeTranscriptSample.FullName } else { $null }

$claudeTasksPattern = if ($claudeDataRoot) { "$claudeDataRoot\tasks\**\*.json" } else { $null }
$claudeTasksExist = if ($claudeTasksPattern) { Test-AnyFile $claudeTasksPattern } else { $false }

$claudeGlobalStatePath = "$env:USERPROFILE\.claude.json"
$claudeGlobalStateExists = Test-Path $claudeGlobalStatePath

$statusLinePath = "$env:LOCALAPPDATA\codexU\claude-code\statusline-snapshot.json"
$statusLineExists = Test-Path $statusLinePath

# ==================== 生成 findings.yaml ====================

$schemaResult = if ($state5Path) { Test-SqliteSchema $state5Path } else { $null }
$appServerResult = Test-AppServer

$findings = [ordered]@{
    generated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    codex = [ordered]@{
        supported = ($null -ne $codexDataRoot)
        data_root = $codexDataRoot
        state_5_sqlite = [ordered]@{
            exists = ($null -ne $state5Path)
            path = $state5Path
            schema_matches_macos = if ($schemaResult) { ($schemaResult.has_threads_table -and $schemaResult.has_rollout_path -and $schemaResult.has_thread_spawn_edges) } else { $false }
            schema_notes = if ($schemaResult) { $schemaResult.notes } else { "database not found" }
        }
        sessions_jsonl = [ordered]@{
            exists = ($null -ne $codexJsonlSample)
            pattern = $codexJsonlPattern
            sample_path = if ($codexJsonlSample) { $codexJsonlSample.FullName } else { $null }
            event_types = @($codexJsonlFields | Where-Object { $_ -in @("token_count", "task_started", "task_complete") })
            all_fields = @($codexJsonlFields)
            has_bom = $codexJsonlHasBOM
        }
        automations = [ordered]@{
            exists = $automationExists
            pattern = $automationPattern
        }
        app_server = [ordered]@{
            available = $appServerResult.available
            notes = $appServerResult.notes
        }
    }
    claude_code = [ordered]@{
        supported = ($null -ne $claudeDataRoot)
        data_root = $claudeDataRoot
        transcripts = [ordered]@{
            exists = ($null -ne $claudeTranscriptSample)
            pattern = $claudeTranscriptPattern
            sample_path = if ($claudeTranscriptSample) { $claudeTranscriptSample.FullName } else { $null }
            fields = @($claudeTranscriptFields)
            has_bom = $claudeTranscriptHasBOM
        }
        tasks = [ordered]@{
            exists = $claudeTasksExist
            pattern = $claudeTasksPattern
        }
        global_state = [ordered]@{
            exists = $claudeGlobalStateExists
            path = $claudeGlobalStatePath
        }
        statusline_snapshot = [ordered]@{
            exists = $statusLineExists
            path = $statusLinePath
            notes = if (-not $statusLineExists) { "Run Claude Code with codexU integration to generate" } else { "found" }
        }
    }
    risk_assessment = @()
    recommendation = "TBD"
}

# 风险评估
$risk = [System.Collections.Generic.List[string]]::new()
if (-not $findings.codex.supported) { $risk.Add("Codex data root not found. May need to install/run Codex CLI first.") }
if (-not $findings.codex.state_5_sqlite.exists) { $risk.Add("state_5.sqlite not found. Codex provider cannot read thread metadata.") }
if ($findings.codex.state_5_sqlite.exists -and -not $findings.codex.state_5_sqlite.schema_matches_macos) { $risk.Add("state_5.sqlite schema differs from macOS. Parser may need adaptation.") }
if (-not $findings.codex.sessions_jsonl.exists) { $risk.Add("Codex JSONL sessions not found. Token breakdown may be unavailable.") }
if (-not $findings.codex.app_server.available) { $risk.Add("codex app-server unavailable. Quota display may rely on local data only.") }
if ($findings.codex.sessions_jsonl.has_bom -eq $true) { $risk.Add("Codex JSONL has UTF-8 BOM. Parser must handle BOM.") }
if (-not $findings.claude_code.supported) { $risk.Add("Claude Code data root not found. Claude Code provider can be deferred.") }

$findings.risk_assessment = $risk.ToArray()

# 推荐
if (-not $findings.codex.supported -and -not $findings.claude_code.supported) {
    $findings.recommendation = "STOP: No Codex or Claude Code data found. Install and use the tools first, then re-run probe."
}
elseif ($findings.codex.supported -and $findings.codex.state_5_sqlite.schema_matches_macos) {
    $findings.recommendation = "GO: Enter phase-1-core-prototype. Consider deferring Claude Code provider if its data is missing."
}
elseif ($findings.codex.supported) {
    $findings.recommendation = "CAUTION: Enter phase-1-core-prototype with reduced scope. Adapt parsers for schema differences."
}
else {
    $findings.recommendation = "DEFER: Wait for Codex Windows support or focus on Claude Code only."
}

# 输出 YAML（简单格式）
function Write-YamlValue {
    param($Value, [int]$Indent = 0)
    $prefix = " " * $Indent
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            $val = $Value[$key]
            if ($val -is [System.Collections.IDictionary]) {
                "$prefix$key`:"
                Write-YamlValue $val ($Indent + 2)
            }
            elseif ($val -is [array]) {
                "$prefix$key`:"
                foreach ($item in $val) {
                    if ($item -is [System.Collections.IDictionary]) {
                        "$prefix  -"
                        foreach ($k in $item.Keys) {
                            "    $k`: $($item[$k])"
                        }
                    }
                    else {
                        "$prefix  - $(Escape-Yaml $item)"
                    }
                }
            }
            else {
                "$prefix$key`: $(Escape-Yaml $val)"
            }
        }
    }
}

function Escape-Yaml {
    param($Value)
    if ($null -eq $Value) { return "null" }
    if ($Value -is [bool]) { return $Value.ToString().ToLower() }
    $str = $Value.ToString()
    if ($str -match "[\:\[\]\{\}\,\&\*\#\?\|\-\<\>\=\!\%\\@\`]" -or $str -match "^\s|\s$" -or $str -eq "") {
        return '"' + $str.Replace('\\', '\\\\').Replace('"', '\\"') + '"'
    }
    return $str
}

$output = [System.Text.StringBuilder]::new()
[void]$output.AppendLine("# codexU Windows Data Path Findings")
[void]$output.AppendLine("# Generated: $($findings.generated_at)")
[void]$output.AppendLine("")

[void]$output.AppendLine("codex:")
[void]$output.AppendLine("  supported: $(Escape-Yaml $findings.codex.supported)")
[void]$output.AppendLine("  data_root: $(Escape-Yaml $findings.codex.data_root)")
[void]$output.AppendLine("  state_5_sqlite:")
[void]$output.AppendLine("    exists: $(Escape-Yaml $findings.codex.state_5_sqlite.exists)")
[void]$output.AppendLine("    path: $(Escape-Yaml $findings.codex.state_5_sqlite.path)")
[void]$output.AppendLine("    schema_matches_macos: $(Escape-Yaml $findings.codex.state_5_sqlite.schema_matches_macos)")
[void]$output.AppendLine("    schema_notes: $(Escape-Yaml $findings.codex.state_5_sqlite.schema_notes)")
[void]$output.AppendLine("  sessions_jsonl:")
[void]$output.AppendLine("    exists: $(Escape-Yaml $findings.codex.sessions_jsonl.exists)")
[void]$output.AppendLine("    pattern: $(Escape-Yaml $findings.codex.sessions_jsonl.pattern)")
[void]$output.AppendLine("    sample_path: $(Escape-Yaml $findings.codex.sessions_jsonl.sample_path)")
[void]$output.AppendLine("    event_types:")
foreach ($f in $findings.codex.sessions_jsonl.event_types) { [void]$output.AppendLine("      - $(Escape-Yaml $f)") }
[void]$output.AppendLine("    all_fields:")
foreach ($f in $findings.codex.sessions_jsonl.all_fields) { [void]$output.AppendLine("      - $(Escape-Yaml $f)") }
[void]$output.AppendLine("    has_bom: $(Escape-Yaml $findings.codex.sessions_jsonl.has_bom)")
[void]$output.AppendLine("  automations:")
[void]$output.AppendLine("    exists: $(Escape-Yaml $findings.codex.automations.exists)")
[void]$output.AppendLine("    pattern: $(Escape-Yaml $findings.codex.automations.pattern)")
[void]$output.AppendLine("  app_server:")
[void]$output.AppendLine("    available: $(Escape-Yaml $findings.codex.app_server.available)")
[void]$output.AppendLine("    notes: $(Escape-Yaml $findings.codex.app_server.notes)")

[void]$output.AppendLine("")
[void]$output.AppendLine("claude_code:")
[void]$output.AppendLine("  supported: $(Escape-Yaml $findings.claude_code.supported)")
[void]$output.AppendLine("  data_root: $(Escape-Yaml $findings.claude_code.data_root)")
[void]$output.AppendLine("  transcripts:")
[void]$output.AppendLine("    exists: $(Escape-Yaml $findings.claude_code.transcripts.exists)")
[void]$output.AppendLine("    pattern: $(Escape-Yaml $findings.claude_code.transcripts.pattern)")
[void]$output.AppendLine("    sample_path: $(Escape-Yaml $findings.claude_code.transcripts.sample_path)")
[void]$output.AppendLine("    fields:")
foreach ($f in $findings.claude_code.transcripts.fields) { [void]$output.AppendLine("      - $(Escape-Yaml $f)") }
[void]$output.AppendLine("    has_bom: $(Escape-Yaml $findings.claude_code.transcripts.has_bom)")
[void]$output.AppendLine("  tasks:")
[void]$output.AppendLine("    exists: $(Escape-Yaml $findings.claude_code.tasks.exists)")
[void]$output.AppendLine("    pattern: $(Escape-Yaml $findings.claude_code.tasks.pattern)")
[void]$output.AppendLine("  global_state:")
[void]$output.AppendLine("    exists: $(Escape-Yaml $findings.claude_code.global_state.exists)")
[void]$output.AppendLine("    path: $(Escape-Yaml $findings.claude_code.global_state.path)")
[void]$output.AppendLine("  statusline_snapshot:")
[void]$output.AppendLine("    exists: $(Escape-Yaml $findings.claude_code.statusline_snapshot.exists)")
[void]$output.AppendLine("    path: $(Escape-Yaml $findings.claude_code.statusline_snapshot.path)")
[void]$output.AppendLine("    notes: $(Escape-Yaml $findings.claude_code.statusline_snapshot.notes)")

[void]$output.AppendLine("")
[void]$output.AppendLine("risk_assessment:")
foreach ($r in $findings.risk_assessment) { [void]$output.AppendLine("  - $(Escape-Yaml $r)") }
[void]$output.AppendLine("")
[void]$output.AppendLine("recommendation: $(Escape-Yaml $findings.recommendation)")

$output.ToString() | Out-File -FilePath $OutputPath -Encoding utf8

Write-Host "`n========== codexU Windows Data Path Probe ==========" -ForegroundColor Cyan
Write-Host "Codex data root:     $($findings.codex.data_root)"
Write-Host "state_5.sqlite:      $($findings.codex.state_5_sqlite.path)"
Write-Host "Codex JSONL found:   $($findings.codex.sessions_jsonl.exists)"
Write-Host "Claude data root:    $($findings.claude_code.data_root)"
Write-Host "Claude JSONL found:  $($findings.claude_code.transcripts.exists)"
Write-Host "app-server available:$($findings.codex.app_server.available)"
Write-Host "Recommendation:      $($findings.recommendation)"
Write-Host "`nFull findings written to: $OutputPath" -ForegroundColor Green
