$ErrorActionPreference = 'Stop'

function Assert-True {
  param([bool] $Condition, [string] $Message)
  if (-not $Condition) {
    throw $Message
  }
}

function Assert-Sequence {
  param([object[]] $Actual, [object[]] $Expected, [string] $Message)
  $actualJson = ConvertTo-Json @($Actual) -Compress
  $expectedJson = ConvertTo-Json @($Expected) -Compress
  if ($actualJson -ne $expectedJson) {
    throw "$Message Expected $expectedJson but received $actualJson."
  }
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$entry = Join-Path $repositoryRoot 'windows\scripts\Capture-NativeVisuals.ps1'
$powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
$preflightOutput = Join-Path $repositoryRoot (
  '.local-artifacts\windows-visual-captures\preflight-contract-' + [guid]::NewGuid().ToString('N')
)

Assert-True (Test-Path -LiteralPath $entry -PathType Leaf) 'The formal native visual capture entry point is missing.'

$output = @(
  & $powershell -NoProfile -ExecutionPolicy Bypass -File $entry `
    -PreflightOnly `
    -OutputRoot $preflightOutput 2>&1
)
$exitCode = $LASTEXITCODE
Assert-True ($exitCode -eq 0) "Preflight failed with exit code $exitCode."

$manifestLine = @($output | Where-Object { "$_".StartsWith('NATIVE_VISUAL_PREFLIGHT=') })
Assert-True ($manifestLine.Count -eq 1) 'Preflight did not emit exactly one machine-readable manifest.'
$manifest = "$($manifestLine[0])".Substring('NATIVE_VISUAL_PREFLIGHT='.Length) | ConvertFrom-Json

Assert-True ($manifest.capture_engine -eq 'Windows.Graphics.Capture') 'Preflight selected the wrong capture engine.'
Assert-True ($manifest.targeting -eq 'exact HWND') 'Preflight did not declare exact-HWND targeting.'
Assert-Sequence @($manifest.client_sizes) @('960x760', '720x540') 'Preflight client-size coverage changed.'
Assert-Sequence @($manifest.surfaces) @('Overview', 'Tasks', 'AI Leadership', 'Usage', 'Projects', 'Skills') 'Preflight surface coverage changed.'
Assert-True ($manifest.app_executable_relative -eq 'windows/target/release/codexu-tauri.exe') 'Preflight selected the wrong release executable.'
Assert-True ($manifest.build_command -eq 'cargo +stable-x86_64-pc-windows-msvc tauri build --no-bundle') 'Preflight selected the wrong release build command.'
Assert-True ([bool]$manifest.prerequisites.csharp_compiler) 'Preflight did not locate the C# compiler.'
Assert-True ([bool]$manifest.prerequisites.windows_metadata) 'Preflight did not locate Windows SDK metadata.'
Assert-True (
  "$($manifest.prerequisites.windows_metadata_version)" -match '^\d+\.\d+\.\d+\.\d+$'
) 'Preflight did not select versioned Windows UnionMetadata.'
Assert-True ([bool]$manifest.prerequisites.ui_automation) 'Preflight did not validate UI Automation.'
Assert-True ([bool]$manifest.prerequisites.native_driver) 'Preflight did not load the native sizing and renderer driver.'
Assert-True (
  $manifest.dpi_scaling_probe -eq '720x540@144=>1080x810'
) 'Preflight did not apply window-DPI scaling to logical client sizes.'
Assert-True (-not [bool]$manifest.writes_performed) 'Preflight unexpectedly wrote runtime artifacts.'
Assert-True (-not (Test-Path -LiteralPath $preflightOutput)) 'Preflight created the requested runtime output directory.'

$defaultOutput = @(
  & $powershell -NoProfile -ExecutionPolicy Bypass -File $entry -PreflightOnly 2>&1
)
$defaultExitCode = $LASTEXITCODE
Assert-True ($defaultExitCode -eq 0) "Default preflight failed with exit code $defaultExitCode."
$defaultManifestLine = @(
  $defaultOutput | Where-Object { "$_".StartsWith('NATIVE_VISUAL_PREFLIGHT=') }
)
Assert-True ($defaultManifestLine.Count -eq 1) 'Default preflight did not emit exactly one manifest.'
$defaultManifest = "$($defaultManifestLine[0])".Substring(
  'NATIVE_VISUAL_PREFLIGHT='.Length
) | ConvertFrom-Json
$defaultLeaf = Split-Path -Leaf $defaultManifest.output_root
Assert-True (
  $defaultLeaf -match '^\d{4}-\d{2}-\d{2}-\d{6}-\d{3}-native-workflow$'
) 'The default timestamped output directory name was not literal and stable.'
Assert-True (
  -not (Test-Path -LiteralPath $defaultManifest.output_root)
) 'Default preflight created its proposed runtime output directory.'

$outsideRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
  'codexu-native-visual-invalid-' + [guid]::NewGuid().ToString('N')
)
$previousErrorActionPreference = $ErrorActionPreference
try {
  $ErrorActionPreference = 'Continue'
  $invalidOutput = @(
    & $powershell -NoProfile -ExecutionPolicy Bypass -File $entry `
      -PreflightOnly `
      -OutputRoot $outsideRoot 2>&1
  )
  $invalidExitCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $previousErrorActionPreference
}
Assert-True ($invalidExitCode -ne 0) 'An output path outside .local-artifacts was accepted.'
Assert-True (-not (Test-Path -LiteralPath $outsideRoot)) 'The rejected output path was created.'

$entrySource = Get-Content -LiteralPath $entry -Raw -Encoding UTF8
Assert-True (
  $entrySource.Contains('$scrollSettleMilliseconds = 650')
) 'Framing must wait for WebView2 smooth scrolling to settle between wheel messages.'
Assert-True (
  $entrySource.Contains('if ($tabVisible -and $panelVisible) {')
) 'Framing must prefer the selected tab target before accepting a page-end fallback.'

Write-Output 'PASS: native visual capture preflight and local-artifact boundary'
