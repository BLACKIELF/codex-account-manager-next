$ErrorActionPreference = 'Stop'

function Assert-True {
  param([bool] $Condition, [string] $Message)

  if (-not $Condition) {
    throw $Message
  }
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$activeFiles = @(
  'windows\README.md',
  'docs\windows-port\blueprint\schema.yaml',
  'docs\windows-port\blueprint\diagram.mmd',
  'docs\windows-port\blueprint\BLUEPRINT.md'
)
$times = [char]0x00D7
$maximized = [string]::Concat([char]0x6700, [char]0x5927, [char]0x5316)
$overviewSingleViewport = -join @('Overview ', [char]0x4EC5, [char]0x91C7, [char]0x96C6, [char]0x4E00, [char]0x4E2A, [char]0x9876, [char]0x90E8, ' viewport')
$dynamicLongPanels = -join @('Tasks', [char]0x3001, 'AI Leadership', [char]0x3001, 'Usage ', [char]0x4E0E, ' Skills ', [char]0x4F7F, [char]0x7528, [char]0x52A8, [char]0x6001, [char]0x7F16, [char]0x53F7, [char]0x7684, ' panel segments')
$projectsFirstViewport = -join @('Projects ', [char]0x4EC5, [char]0x91C7, [char]0x96C6, [char]0x4E00, [char]0x4E2A, $maximized, [char]0x7684, [char]0x9996, [char]0x4E2A, ' viewport')
$obsoletePatterns = @(
  "960${times}760",
  "720${times}540",
  '12 PNGs',
  'Native Screenshot Demo'
)

$contentByFile = @{}
$violations = @()
foreach ($relativePath in $activeFiles) {
  $path = Join-Path $repositoryRoot $relativePath
  Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Active documentation source is missing: $relativePath"

  $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  $contentByFile[$relativePath] = $content
  foreach ($pattern in $obsoletePatterns) {
    if ($relativePath -eq 'docs\windows-port\blueprint\BLUEPRINT.md' -and ($pattern -eq '12 PNGs' -or $pattern -eq 'Native Screenshot Demo')) {
      continue
    }
    if ($content.Contains($pattern)) {
      $violations += "${relativePath}:$pattern"
    }
  }
}

if ($violations.Count -gt 0) {
  throw "Obsolete active native-visual documentation found: $($violations -join '; ')"
}

$readme = $contentByFile['windows\README.md'] -replace '[\r\n]', ''
Assert-True ($readme.Contains($maximized)) 'windows/README.md must document maximized capture.'
Assert-True ($readme.Contains('exact HWND')) 'windows/README.md must document exact-HWND capture.'
Assert-True ($readme.Contains('-Surface Skills')) 'windows/README.md must include the focused Skills capture example.'
Assert-True ($readme.Contains($overviewSingleViewport)) 'windows/README.md must make Overview a single top viewport.'
Assert-True ($readme.Contains($dynamicLongPanels)) 'windows/README.md must reserve dynamic numbered panel segments for the four long panels.'
Assert-True ($readme.Contains($projectsFirstViewport)) 'windows/README.md must retain the single Projects first viewport.'
Assert-True ($contentByFile['docs\windows-port\blueprint\schema.yaml'].Contains('Maximized Capture Workflow')) 'schema.yaml must name the maximized capture workflow.'
Assert-True ($contentByFile['docs\windows-port\blueprint\schema.yaml'].Contains('dynamic PNGs')) 'schema.yaml must document dynamic PNG evidence.'

$blueprint = $contentByFile['docs\windows-port\blueprint\BLUEPRINT.md']
Assert-True ($blueprint.Contains('2026-08-03')) 'BLUEPRINT.md must record the 2026-08-03 two-label edit provenance.'
Assert-True ($blueprint.Contains('Native Screenshot Demo') -and $blueprint.Contains('Maximized Capture Workflow')) 'BLUEPRINT.md must record the workflow-label edit provenance.'
Assert-True ($blueprint.Contains('manifest + 12 PNGs') -and $blueprint.Contains('manifest + dynamic PNGs')) 'BLUEPRINT.md must record the evidence-label edit provenance.'
Assert-True (([regex]::Matches($blueprint, 'Native Screenshot Demo')).Count -eq 1) 'BLUEPRINT.md must not retain stale workflow-label occurrences outside provenance.'
Assert-True (([regex]::Matches($blueprint, '12 PNGs')).Count -eq 1) 'BLUEPRINT.md must not retain stale fixed-count evidence occurrences outside provenance.'

$reportFiles = @(
  'docs\windows-port\reports\WINDOWS_MAXIMIZED_NATIVE_VISUAL_WORKFLOW_REPORT.md',
  'docs\windows-port\reports\WINDOWS_MAXIMIZED_NATIVE_VISUAL_WORKFLOW_REPORT.html'
)
foreach ($relativePath in $reportFiles) {
  $path = Join-Path $repositoryRoot $relativePath
  Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Maximized workflow report is missing: $relativePath"
  $report = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  $reportText = ([regex]::Replace($report, '<[^>]+>', '')) -replace '`', ''
  Assert-True ($reportText.Contains('PowerShell parser: 4/4 passed.')) "$relativePath must record the parser result."
  Assert-True ($reportText.Contains('Leadership UIA timeout')) "$relativePath must record the intermittent Leadership UIA timeout."
  Assert-True ($reportText.Contains('57.561s')) "$relativePath must record the successful clean-state rerun duration."
  Assert-True ($reportText.Contains('Cause unconfirmed')) "$relativePath must preserve the unconfirmed intermittent-cause warning."
  $reportTextLower = $reportText.ToLowerInvariant()
  Assert-True ($reportTextLower.Contains('formal capture evidence at 301b323')) "$relativePath must distinguish formal-capture evidence from later verification."
  Assert-True ($reportTextLower.Contains('later verification evidence at 4ff0d16')) "$relativePath must distinguish later verification evidence from formal capture."
  Assert-True (-not $reportText.Contains('other identifier')) "$relativePath must reject the overbroad privacy phrase."
  Assert-True ($reportText.Contains('contains no identifier from captured local or product data')) "$relativePath must scope the original privacy prohibition to captured local or product data."
  Assert-True ($reportText.Contains('intentional branch and commit checkout identity')) "$relativePath must allow intentional checkout identity for provenance."
}

Write-Output 'PASS: active native visual documentation matches the maximized capture contract'
