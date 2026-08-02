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
    if ($content.Contains($pattern)) {
      $violations += "${relativePath}:$pattern"
    }
  }
}

if ($violations.Count -gt 0) {
  throw "Obsolete active native-visual documentation found: $($violations -join '; ')"
}

Assert-True ($contentByFile['windows\README.md'].Contains($maximized)) 'windows/README.md must document maximized capture.'
Assert-True ($contentByFile['windows\README.md'].Contains('exact HWND')) 'windows/README.md must document exact-HWND capture.'
Assert-True ($contentByFile['windows\README.md'].Contains('-Surface Skills')) 'windows/README.md must include the focused Skills capture example.'
Assert-True ($contentByFile['docs\windows-port\blueprint\schema.yaml'].Contains('Maximized Capture Workflow')) 'schema.yaml must name the maximized capture workflow.'
Assert-True ($contentByFile['docs\windows-port\blueprint\schema.yaml'].Contains('dynamic PNGs')) 'schema.yaml must document dynamic PNG evidence.'

Write-Output 'PASS: active native visual documentation matches the maximized capture contract'
