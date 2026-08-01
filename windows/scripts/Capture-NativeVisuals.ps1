#Requires -Version 5.1

[CmdletBinding()]
param(
  [string] $OutputRoot,
  [switch] $PreflightOnly,
  [switch] $SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$windowsRoot = Join-Path $repositoryRoot 'windows'
$artifactBase = Join-Path $repositoryRoot '.local-artifacts\windows-visual-captures'
$helperSource = Join-Path $PSScriptRoot 'native-visual-capture\GraphicsCaptureSnapshot.cs'
$appPath = Join-Path $windowsRoot 'target\release\codexu-tauri.exe'
$clientSizes = @(
  [ordered]@{ width = 960; height = 760 },
  [ordered]@{ width = 720; height = 540 }
)
$surfaces = @(
  [ordered]@{
    name = 'Tasks'
    slug = 'tasks'
    tab = 'dashboard-home-tab-tasks'
    panel = 'dashboard-home-panel-tasks'
  },
  [ordered]@{
    name = 'AI Leadership'
    slug = 'ai-leadership'
    tab = 'dashboard-home-tab-leadership'
    panel = 'dashboard-home-panel-leadership'
  },
  [ordered]@{
    name = 'Usage'
    slug = 'usage'
    tab = 'dashboard-home-tab-usage'
    panel = 'dashboard-home-panel-usage'
  },
  [ordered]@{
    name = 'Projects'
    slug = 'projects'
    tab = 'dashboard-home-tab-projects'
    panel = 'dashboard-home-panel-projects'
  },
  [ordered]@{
    name = 'Skills'
    slug = 'skills'
    tab = 'dashboard-home-tab-skills'
    panel = 'dashboard-home-panel-skills'
  }
)

function Get-NormalizedOutputRoot {
  param([string] $RequestedPath)

  if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
    $leaf = (Get-Date).ToString('yyyy-MM-dd-HHmmss-fff') + '-native-workflow'
    $RequestedPath = Join-Path $artifactBase $leaf
  } elseif (-not [System.IO.Path]::IsPathRooted($RequestedPath)) {
    $RequestedPath = Join-Path $repositoryRoot $RequestedPath
  }

  $fullPath = [System.IO.Path]::GetFullPath($RequestedPath)
  $basePath = [System.IO.Path]::GetFullPath($artifactBase)
  $basePrefix = $basePath.TrimEnd([char[]]"\/") + [System.IO.Path]::DirectorySeparatorChar
  if (-not $fullPath.StartsWith(
    $basePrefix,
    [System.StringComparison]::OrdinalIgnoreCase
  )) {
    throw 'OutputRoot must be a new child of .local-artifacts/windows-visual-captures.'
  }
  return $fullPath
}

function Get-CaptureCompiler {
  $windowsDirectory = [Environment]::GetFolderPath(
    [Environment+SpecialFolder]::Windows
  )
  $frameworkCandidates = @(
    (Join-Path $windowsDirectory 'Microsoft.NET\Framework64\v4.0.30319'),
    (Join-Path $windowsDirectory 'Microsoft.NET\Framework\v4.0.30319')
  )
  $frameworkDirectory = @(
    $frameworkCandidates | Where-Object {
      Test-Path -LiteralPath (Join-Path $_ 'csc.exe') -PathType Leaf
    }
  ) | Select-Object -First 1

  $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
  $metadataCandidates = @()
  if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
    $unionMetadata = Join-Path $programFilesX86 'Windows Kits\10\UnionMetadata'
    if (Test-Path -LiteralPath $unionMetadata -PathType Container) {
      $metadataCandidates = @(
        Get-ChildItem -LiteralPath $unionMetadata -Directory |
          Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
          Sort-Object { [version]$_.Name } -Descending |
          ForEach-Object {
            Get-Item -LiteralPath (Join-Path $_.FullName 'Windows.winmd') `
              -ErrorAction SilentlyContinue
          }
      )
    }
  }
  $windowsMetadataItem = @($metadataCandidates) | Select-Object -First 1
  $windowsMetadata = $null
  $windowsMetadataVersion = $null
  if ($null -ne $windowsMetadataItem) {
    $windowsMetadata = $windowsMetadataItem.FullName
    $windowsMetadataVersion = $windowsMetadataItem.Directory.Name
  }

  $compiler = $null
  $runtimeWindows = $null
  $runtime = $null
  $drawing = $null
  if ($null -ne $frameworkDirectory) {
    $compiler = Join-Path $frameworkDirectory 'csc.exe'
    $runtimeWindows = Join-Path $frameworkDirectory 'System.Runtime.WindowsRuntime.dll'
    $runtime = Join-Path $frameworkDirectory 'System.Runtime.dll'
    $drawing = Join-Path $frameworkDirectory 'System.Drawing.dll'
  }

  return [pscustomobject]@{
    compiler = $compiler
    windows_metadata = $windowsMetadata
    windows_metadata_version = $windowsMetadataVersion
    runtime_windows = $runtimeWindows
    runtime = $runtime
    drawing = $drawing
  }
}

function Test-CompilerReady {
  param([pscustomobject] $Compiler)
  return (
    $null -ne $Compiler.compiler -and
    $null -ne $Compiler.windows_metadata -and
    (Test-Path -LiteralPath $Compiler.compiler -PathType Leaf) -and
    (Test-Path -LiteralPath $Compiler.windows_metadata -PathType Leaf) -and
    (Test-Path -LiteralPath $Compiler.runtime_windows -PathType Leaf) -and
    (Test-Path -LiteralPath $Compiler.runtime -PathType Leaf) -and
    (Test-Path -LiteralPath $Compiler.drawing -PathType Leaf)
  )
}

function Initialize-NativeVisualDriver {
  if ($null -ne ('NativeVisualCaptureDriver' -as [type])) {
    return
  }

  Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class NativeVisualCaptureDriver
{
    private const uint SWP_NOZORDER = 0x0004;
    private const uint SWP_NOACTIVATE = 0x0010;
    private const uint WM_MOUSEWHEEL = 0x020A;
    private const uint WM_MOUSEHWHEEL = 0x020E;

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int X;
        public int Y;
    }

    private delegate bool EnumChildProc(IntPtr hwnd, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetClientRect(IntPtr hwnd, out RECT rect);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool ClientToScreen(IntPtr hwnd, ref POINT point);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(
        IntPtr hwnd,
        IntPtr insertAfter,
        int x,
        int y,
        int width,
        int height,
        uint flags
    );

    [DllImport("user32.dll")]
    private static extern uint GetDpiForWindow(IntPtr hwnd);

    [DllImport("user32.dll")]
    private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr value);

    [DllImport("user32.dll")]
    private static extern bool EnumChildWindows(
        IntPtr parent,
        EnumChildProc callback,
        IntPtr lParam
    );

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(
        IntPtr hwnd,
        StringBuilder text,
        int maxCount
    );

    [DllImport("user32.dll")]
    private static extern bool PostMessage(
        IntPtr hwnd,
        uint message,
        IntPtr wParam,
        IntPtr lParam
    );

    private static RECT ReadWindowRect(IntPtr hwnd)
    {
        RECT rect;
        if (!GetWindowRect(hwnd, out rect))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        return rect;
    }

    private static RECT ReadClientRect(IntPtr hwnd)
    {
        RECT rect;
        if (!GetClientRect(hwnd, out rect))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        return rect;
    }

    private static int ScaleForDpi(int logicalValue, uint dpi)
    {
        return checked((int)Math.Round(
            logicalValue * (double)dpi / 96.0,
            MidpointRounding.AwayFromZero
        ));
    }

    private static int UnscaleForDpi(int physicalValue, uint dpi)
    {
        return checked((int)Math.Round(
            physicalValue * 96.0 / dpi,
            MidpointRounding.AwayFromZero
        ));
    }

    public static string GetPhysicalClientTarget(
        int logicalWidth,
        int logicalHeight,
        uint dpi
    )
    {
        return String.Format(
            "{0}x{1}",
            ScaleForDpi(logicalWidth, dpi),
            ScaleForDpi(logicalHeight, dpi)
        );
    }

    public static string SetClientSizeAndDescribe(
        IntPtr hwnd,
        int clientWidth,
        int clientHeight
    )
    {
        IntPtr previousDpiContext = SetThreadDpiAwarenessContext(new IntPtr(-4));
        try
        {
            uint dpi = GetDpiForWindow(hwnd);
            int targetClientWidth = ScaleForDpi(clientWidth, dpi);
            int targetClientHeight = ScaleForDpi(clientHeight, dpi);

            for (int attempt = 0; attempt < 4; attempt++)
            {
                RECT window = ReadWindowRect(hwnd);
                RECT client = ReadClientRect(hwnd);
                int currentClientWidth = client.Right - client.Left;
                int currentClientHeight = client.Bottom - client.Top;
                if (
                    currentClientWidth == targetClientWidth &&
                    currentClientHeight == targetClientHeight
                )
                {
                    break;
                }

                int targetWindowWidth =
                    (window.Right - window.Left) +
                    targetClientWidth -
                    currentClientWidth;
                int targetWindowHeight =
                    (window.Bottom - window.Top) +
                    targetClientHeight -
                    currentClientHeight;
                if (!SetWindowPos(
                    hwnd,
                    IntPtr.Zero,
                    window.Left,
                    window.Top,
                    targetWindowWidth,
                    targetWindowHeight,
                    SWP_NOZORDER | SWP_NOACTIVATE
                ))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }
                Thread.Sleep(250);
            }

            RECT finalWindow = ReadWindowRect(hwnd);
            RECT finalClient = ReadClientRect(hwnd);
            int finalPhysicalWidth = finalClient.Right - finalClient.Left;
            int finalPhysicalHeight = finalClient.Bottom - finalClient.Top;
            return String.Format(
                "client={0}x{1};clientPhysical={2}x{3};outer={4}x{5};dpi={6}",
                UnscaleForDpi(finalPhysicalWidth, dpi),
                UnscaleForDpi(finalPhysicalHeight, dpi),
                finalPhysicalWidth,
                finalPhysicalHeight,
                finalWindow.Right - finalWindow.Left,
                finalWindow.Bottom - finalWindow.Top,
                dpi
            );
        }
        finally
        {
            if (previousDpiContext != IntPtr.Zero)
            {
                SetThreadDpiAwarenessContext(previousDpiContext);
            }
        }
    }

    public static string GetClientScreenBounds(IntPtr hwnd)
    {
        IntPtr previousDpiContext = SetThreadDpiAwarenessContext(new IntPtr(-4));
        try
        {
            RECT client = ReadClientRect(hwnd);
            var origin = new POINT { X = 0, Y = 0 };
            if (!ClientToScreen(hwnd, ref origin))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }
            return String.Format(
                "left={0};top={1};right={2};bottom={3}",
                origin.X,
                origin.Y,
                origin.X + client.Right - client.Left,
                origin.Y + client.Bottom - client.Top
            );
        }
        finally
        {
            if (previousDpiContext != IntPtr.Zero)
            {
                SetThreadDpiAwarenessContext(previousDpiContext);
            }
        }
    }

    public static IntPtr FindRenderer(IntPtr parent)
    {
        IntPtr result = IntPtr.Zero;
        EnumChildWindows(
            parent,
            delegate(IntPtr hwnd, IntPtr lParam)
            {
                var name = new StringBuilder(256);
                GetClassName(hwnd, name, name.Capacity);
                if (name.ToString() == "Chrome_RenderWidgetHostHWND")
                {
                    result = hwnd;
                    return false;
                }
                return true;
            },
            IntPtr.Zero
        );
        return result;
    }

    public static bool ScrollRenderer(IntPtr renderer, int wheelDelta, int count)
    {
        RECT rect = ReadWindowRect(renderer);
        int x = (rect.Left + rect.Right) / 2;
        int y = rect.Top + ((rect.Bottom - rect.Top) * 3 / 4);
        long lParamValue =
            ((long)(y & 0xffff) << 16) | (uint)(x & 0xffff);
        long wParamValue = ((long)(wheelDelta & 0xffff) << 16);
        bool delivered = true;
        for (int index = 0; index < count; index++)
        {
            delivered =
                PostMessage(
                    renderer,
                    WM_MOUSEWHEEL,
                    new IntPtr(wParamValue),
                    new IntPtr(lParamValue)
                ) && delivered;
        }
        return delivered;
    }

    public static bool ScrollRendererHorizontal(
        IntPtr renderer,
        int wheelDelta,
        int count
    )
    {
        IntPtr previousDpiContext = SetThreadDpiAwarenessContext(new IntPtr(-4));
        try
        {
            RECT rect = ReadWindowRect(renderer);
            int x = (rect.Left + rect.Right) / 2;
            int y = (rect.Top + rect.Bottom) / 2;
            long lParamValue =
                ((long)(y & 0xffff) << 16) | (uint)(x & 0xffff);
            long wParamValue = ((long)(wheelDelta & 0xffff) << 16);
            bool delivered = true;
            for (int index = 0; index < count; index++)
            {
                delivered =
                    PostMessage(
                        renderer,
                        WM_MOUSEHWHEEL,
                        new IntPtr(wParamValue),
                        new IntPtr(lParamValue)
                    ) && delivered;
            }
            return delivered;
        }
        finally
        {
            if (previousDpiContext != IntPtr.Zero)
            {
                SetThreadDpiAwarenessContext(previousDpiContext);
            }
        }
    }
}
'@
}

function Get-PreflightManifest {
  param([string] $ResolvedOutputRoot, [pscustomobject] $Compiler)

  $uiAutomationReady = $true
  try {
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
  } catch {
    $uiAutomationReady = $false
  }
  $nativeDriverReady = $true
  try {
    Initialize-NativeVisualDriver
  } catch {
    $nativeDriverReady = $false
  }

  $cargo = Get-Command cargo.exe -ErrorAction SilentlyContinue
  if ($null -eq $cargo) {
    $cargo = Get-Command cargo -ErrorAction SilentlyContinue
  }
  $git = Get-Command git.exe -ErrorAction SilentlyContinue
  if ($null -eq $git) {
    $git = Get-Command git -ErrorAction SilentlyContinue
  }

  return [ordered]@{
    capture_engine = 'Windows.Graphics.Capture'
    targeting = 'exact HWND'
    dpi_scaling_probe = (
      '720x540@144=>' +
      [NativeVisualCaptureDriver]::GetPhysicalClientTarget(720, 540, 144)
    )
    client_sizes = @($clientSizes | ForEach-Object { "$($_.width)x$($_.height)" })
    surfaces = @('Overview') + @($surfaces | ForEach-Object { $_.name })
    build_command = 'cargo +stable-x86_64-pc-windows-msvc tauri build --no-bundle'
    app_executable_relative = 'windows/target/release/codexu-tauri.exe'
    output_root = $ResolvedOutputRoot
    prerequisites = [ordered]@{
      windows = (
        [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
      )
      cargo = ($null -ne $cargo)
      git = ($null -ne $git)
      helper_source = (Test-Path -LiteralPath $helperSource -PathType Leaf)
      csharp_compiler = (Test-CompilerReady -Compiler $Compiler)
      windows_metadata = (
        $null -ne $Compiler.windows_metadata -and
        (Test-Path -LiteralPath $Compiler.windows_metadata -PathType Leaf)
      )
      windows_metadata_version = $Compiler.windows_metadata_version
      ui_automation = $uiAutomationReady
      native_driver = $nativeDriverReady
    }
    writes_performed = $false
  }
}

function Assert-PreflightReady {
  param([System.Collections.IDictionary] $Preflight)
  $missing = @(
    $Preflight.prerequisites.GetEnumerator() |
      Where-Object { -not [bool]$_.Value } |
      ForEach-Object { $_.Key }
  )
  if ($missing.Count -gt 0) {
    throw ('Native visual preflight failed: ' + ($missing -join ', '))
  }
}

function Test-OutputRootIgnored {
  param([string] $ResolvedOutputRoot)
  $relative = $ResolvedOutputRoot.Substring($repositoryRoot.Length).TrimStart([char[]]"\/")
  $relative = $relative.Replace('\', '/')
  Push-Location $repositoryRoot
  try {
    & git check-ignore -q -- $relative
    if ($LASTEXITCODE -ne 0) {
      throw 'The local native visual output root is not covered by Git ignore rules.'
    }
  } finally {
    Pop-Location
  }
}

function Invoke-LoggedProcess {
  param(
    [string] $FileName,
    [string[]] $Arguments,
    [string] $WorkingDirectory,
    [string] $LogPath
  )

  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $FileName
  $startInfo.Arguments = ($Arguments -join ' ')
  $startInfo.WorkingDirectory = $WorkingDirectory
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  if (-not $process.Start()) {
    throw "Could not start $FileName."
  }
  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $process.WaitForExit()
  $stdout = $stdoutTask.Result
  $stderr = $stderrTask.Result
  [System.IO.File]::WriteAllText(
    $LogPath,
    $stdout + [Environment]::NewLine + $stderr,
    [System.Text.UTF8Encoding]::new($false)
  )
  if ($process.ExitCode -ne 0) {
    throw "$FileName failed with exit code $($process.ExitCode). See the local run log."
  }
}

function Build-CaptureHelper {
  param(
    [pscustomobject] $Compiler,
    [string] $OutputPath,
    [string] $LogPath
  )
  $arguments = @(
    '/nologo',
    '/target:exe',
    "/out:$OutputPath",
    "/reference:$($Compiler.windows_metadata)",
    "/reference:$($Compiler.runtime_windows)",
    "/reference:$($Compiler.runtime)",
    "/reference:$($Compiler.drawing)",
    $helperSource
  )
  $compilerOutput = @(& $Compiler.compiler @arguments 2>&1)
  $compilerExitCode = $LASTEXITCODE
  $compilerOutput | Out-File -LiteralPath $LogPath -Encoding utf8
  if ($compilerExitCode -ne 0) {
    throw "Graphics capture helper compilation failed with exit code $compilerExitCode."
  }
  if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
    throw 'Graphics capture helper compilation did not create the expected executable.'
  }
}

function Get-ProcessIdentity {
  param([int] $ProcessId)
  $process = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" `
    -ErrorAction SilentlyContinue
  if ($null -eq $process) {
    return $null
  }
  $creation = $null
  if ($null -ne $process.CreationDate) {
    $creation = ([datetime]$process.CreationDate).ToUniversalTime().ToString('o')
  }
  return [pscustomobject]@{
    process_id = [int]$process.ProcessId
    parent_process_id = [int]$process.ParentProcessId
    name = [string]$process.Name
    executable_path = [string]$process.ExecutablePath
    creation_utc = $creation
  }
}

function Get-TaskDescendantIdentities {
  param([int] $RootProcessId)
  $all = @(Get-CimInstance Win32_Process)
  $known = [System.Collections.Generic.HashSet[int]]::new()
  $queue = [System.Collections.Generic.Queue[int]]::new()
  [void]$known.Add($RootProcessId)
  $queue.Enqueue($RootProcessId)
  $results = [System.Collections.ArrayList]::new()

  while ($queue.Count -gt 0) {
    $parent = $queue.Dequeue()
    foreach ($candidate in @($all | Where-Object {
      [int]$_.ParentProcessId -eq $parent
    })) {
      $candidateId = [int]$candidate.ProcessId
      if ($known.Add($candidateId)) {
        $queue.Enqueue($candidateId)
        $identity = Get-ProcessIdentity -ProcessId $candidateId
        if ($null -ne $identity) {
          [void]$results.Add($identity)
        }
      }
    }
  }
  return @($results)
}

function Add-RecordedIdentity {
  param(
    [System.Collections.ArrayList] $Records,
    [pscustomobject] $Identity
  )
  if ($null -eq $Identity) {
    return
  }
  $alreadyRecorded = @($Records | Where-Object {
    $_.process_id -eq $Identity.process_id -and
    $_.creation_utc -eq $Identity.creation_utc
  }).Count -gt 0
  if (-not $alreadyRecorded) {
    [void]$Records.Add($Identity)
  }
}

function Update-TaskProcessRecords {
  param(
    [int] $RootProcessId,
    [System.Collections.ArrayList] $Records
  )
  Add-RecordedIdentity -Records $Records -Identity (
    Get-ProcessIdentity -ProcessId $RootProcessId
  )
  foreach ($identity in @(Get-TaskDescendantIdentities -RootProcessId $RootProcessId)) {
    Add-RecordedIdentity -Records $Records -Identity $identity
  }
}

function Test-RecordedIdentity {
  param([pscustomobject] $Recorded, [pscustomobject] $Current)
  if ($null -eq $Current) {
    return $false
  }
  return (
    $Recorded.process_id -eq $Current.process_id -and
    $Recorded.name -eq $Current.name -and
    $Recorded.creation_utc -eq $Current.creation_utc -and
    $Recorded.executable_path -eq $Current.executable_path
  )
}

function Stop-RecordedTaskProcesses {
  param(
    [int] $RootProcessId,
    [System.Collections.ArrayList] $Records
  )

  Update-TaskProcessRecords -RootProcessId $RootProcessId -Records $Records
  $stopped = [System.Collections.ArrayList]::new()
  $alreadyExited = [System.Collections.ArrayList]::new()
  $identityMismatches = [System.Collections.ArrayList]::new()

  $rootRecord = @($Records | Where-Object {
    $_.process_id -eq $RootProcessId
  } | Select-Object -First 1)
  if ($rootRecord.Count -eq 1) {
    $currentRoot = Get-ProcessIdentity -ProcessId $RootProcessId
    if ($null -eq $currentRoot) {
      [void]$alreadyExited.Add($RootProcessId)
    } elseif (Test-RecordedIdentity -Recorded $rootRecord[0] -Current $currentRoot) {
      Stop-Process -Id $RootProcessId -Force -ErrorAction SilentlyContinue
      [void]$stopped.Add($RootProcessId)
    } else {
      [void]$identityMismatches.Add($RootProcessId)
    }
  }

  $rootDeadline = (Get-Date).AddSeconds(8)
  while ((Get-Date) -lt $rootDeadline -and $null -ne (
    Get-ProcessIdentity -ProcessId $RootProcessId
  )) {
    Start-Sleep -Milliseconds 100
  }

  foreach ($record in @($Records | Where-Object {
    $_.process_id -ne $RootProcessId
  } | Sort-Object process_id -Descending)) {
    $current = Get-ProcessIdentity -ProcessId $record.process_id
    if ($null -eq $current) {
      [void]$alreadyExited.Add($record.process_id)
    } elseif (Test-RecordedIdentity -Recorded $record -Current $current) {
      Stop-Process -Id $record.process_id -Force -ErrorAction SilentlyContinue
      [void]$stopped.Add($record.process_id)
    } else {
      [void]$identityMismatches.Add($record.process_id)
    }
  }

  $deadline = (Get-Date).AddSeconds(8)
  do {
    $remaining = @(
      $Records | Where-Object {
        $current = Get-ProcessIdentity -ProcessId $_.process_id
        Test-RecordedIdentity -Recorded $_ -Current $current
      }
    )
    if ($remaining.Count -eq 0) {
      break
    }
    Start-Sleep -Milliseconds 100
  } while ((Get-Date) -lt $deadline)

  return [ordered]@{
    recorded_count = $Records.Count
    stopped_process_ids = @($stopped)
    already_exited_process_ids = @($alreadyExited)
    identity_mismatch_process_ids = @($identityMismatches)
    remaining_matching_process_ids = @($remaining | ForEach-Object { $_.process_id })
  }
}

function Get-ExactExecutableProcesses {
  param([string] $ExecutablePath)
  if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) {
    return @()
  }
  $name = [System.IO.Path]::GetFileName($ExecutablePath).Replace("'", "''")
  return @(
    Get-CimInstance Win32_Process -Filter "Name = '$name'" |
      Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.ExecutablePath) -and
        [string]::Equals(
          [System.IO.Path]::GetFullPath($_.ExecutablePath),
          [System.IO.Path]::GetFullPath($ExecutablePath),
          [System.StringComparison]::OrdinalIgnoreCase
        )
      }
  )
}

function Wait-TaskWindow {
  param([System.Diagnostics.Process] $Process)
  $deadline = (Get-Date).AddSeconds(60)
  do {
    if ($Process.HasExited) {
      throw 'The task application exited before its main window was ready.'
    }
    Start-Sleep -Milliseconds 200
    $Process.Refresh()
  } while ($Process.MainWindowHandle -eq [IntPtr]::Zero -and (Get-Date) -lt $deadline)
  if ($Process.MainWindowHandle -eq [IntPtr]::Zero) {
    throw 'Timed out waiting for the task application main window.'
  }
  return $Process.MainWindowHandle
}

function Find-ElementByAutomationId {
  param([IntPtr] $Window, [string] $AutomationId)
  $root = [System.Windows.Automation.AutomationElement]::FromHandle($Window)
  $condition = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
    $AutomationId
  )
  return $root.FindFirst(
    [System.Windows.Automation.TreeScope]::Descendants,
    $condition
  )
}

function Wait-ForElement {
  param(
    [IntPtr] $Window,
    [string] $AutomationId,
    [int] $TimeoutSeconds = 30
  )
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    $element = Find-ElementByAutomationId -Window $Window -AutomationId $AutomationId
    if ($null -ne $element) {
      return $element
    }
    Start-Sleep -Milliseconds 150
  } while ((Get-Date) -lt $deadline)
  throw "Timed out waiting for UI element $AutomationId."
}

function Select-DashboardTab {
  param([IntPtr] $Window, [string] $TabId, [string] $PanelId)
  $tab = Wait-ForElement -Window $Window -AutomationId $TabId
  $pattern = $tab.GetCurrentPattern(
    [System.Windows.Automation.SelectionItemPattern]::Pattern
  )
  $pattern.Select()
  [void](Wait-ForElement -Window $Window -AutomationId $PanelId -TimeoutSeconds 8)
}

function Get-ClientScreenBounds {
  param([IntPtr] $Window)
  $description = [NativeVisualCaptureDriver]::GetClientScreenBounds($Window)
  if ($description -notmatch '^left=(?<left>-?\d+);top=(?<top>-?\d+);right=(?<right>-?\d+);bottom=(?<bottom>-?\d+)$') {
    throw "Could not parse client screen bounds: $description"
  }
  return [pscustomobject]@{
    left = [int]$Matches.left
    top = [int]$Matches.top
    right = [int]$Matches.right
    bottom = [int]$Matches.bottom
  }
}

function Move-RendererToTop {
  param([IntPtr] $Renderer)
  [void][NativeVisualCaptureDriver]::ScrollRenderer($Renderer, 120, 40)
  Start-Sleep -Milliseconds 500
}

function Move-RendererToLeft {
  param([IntPtr] $Renderer)
  [void][NativeVisualCaptureDriver]::ScrollRendererHorizontal(
    $Renderer,
    -120,
    32
  )
  Start-Sleep -Milliseconds 250
}

function Align-DashboardSurface {
  param(
    [IntPtr] $Window,
    [IntPtr] $Renderer,
    [string] $TabId,
    [string] $PanelId
  )
  $client = Get-ClientScreenBounds -Window $Window
  $clientHeight = $client.bottom - $client.top
  $preferredTabTop = $client.top + [int]($clientHeight * 0.42)
  $scrollSettleMilliseconds = 650
  $lastObservation = $null
  $previousTabTop = $null
  $stableTabTopCount = 0
  for ($step = 0; $step -le 18; $step++) {
    $tab = Wait-ForElement -Window $Window -AutomationId $TabId -TimeoutSeconds 5
    $panel = Wait-ForElement -Window $Window -AutomationId $PanelId -TimeoutSeconds 5
    $tabRect = $tab.Current.BoundingRectangle
    $tabVisible = (
      -not $tab.Current.IsOffscreen -and
      $tabRect.Height -gt 0 -and
      $tabRect.Top -ge $client.top -and
      $tabRect.Top -le $preferredTabTop -and
      $tabRect.Bottom -le ($client.bottom - 180)
    )
    $panelVisible = -not $panel.Current.IsOffscreen
    $basicFramingVisible = (
      -not $tab.Current.IsOffscreen -and
      $tabRect.Height -gt 0 -and
      $tabRect.Top -ge $client.top -and
      $tabRect.Bottom -le ($client.bottom - 180) -and
      $panelVisible
    )
    if ($null -ne $previousTabTop -and [int]$tabRect.Top -eq $previousTabTop) {
      $stableTabTopCount++
    } else {
      $stableTabTopCount = 0
    }
    $previousTabTop = [int]$tabRect.Top
    $lastObservation = [ordered]@{
      step = $step
      tab_offscreen = $tab.Current.IsOffscreen
      panel_offscreen = $panel.Current.IsOffscreen
      tab_top = [int]$tabRect.Top
      tab_bottom = [int]$tabRect.Bottom
      client_top = $client.top
      client_bottom = $client.bottom
      preferred_tab_top = $preferredTabTop
    }
    if ($tabVisible -and $panelVisible) {
      return [ordered]@{
        scroll_steps = $step
        selected_tab_visible = $true
        panel_visible = $true
        tab_top_in_client = [int]($tabRect.Top - $client.top)
        limited_by_page_end = $false
      }
    }
    if ($basicFramingVisible -and $stableTabTopCount -ge 1) {
      return [ordered]@{
        scroll_steps = $step
        selected_tab_visible = $true
        panel_visible = $true
        tab_top_in_client = [int]($tabRect.Top - $client.top)
        limited_by_page_end = $true
      }
    }
    [void][NativeVisualCaptureDriver]::ScrollRenderer($Renderer, -120, 1)
    Start-Sleep -Milliseconds $scrollSettleMilliseconds
  }
  throw (
    "Could not frame $TabId with its selected panel in the same client area. " +
    ($lastObservation | ConvertTo-Json -Compress)
  )
}

function Set-VerifiedClientSize {
  param([IntPtr] $Window, [int] $Width, [int] $Height)
  $description = [NativeVisualCaptureDriver]::SetClientSizeAndDescribe(
    $Window,
    $Width,
    $Height
  )
  if ($description -notmatch '^client=(?<width>\d+)x(?<height>\d+);clientPhysical=(?<physicalWidth>\d+)x(?<physicalHeight>\d+);outer=(?<outerWidth>\d+)x(?<outerHeight>\d+);dpi=(?<dpi>\d+)$') {
    throw "Could not parse verified window dimensions: $description"
  }
  if ([int]$Matches.width -ne $Width -or [int]$Matches.height -ne $Height) {
    throw "Requested client ${Width}x${Height}, received $($Matches.width)x$($Matches.height)."
  }
  return [ordered]@{
    requested_client = "${Width}x${Height}"
    verified_client = "$($Matches.width)x$($Matches.height)"
    physical_client = "$($Matches.physicalWidth)x$($Matches.physicalHeight)"
    outer_window = "$($Matches.outerWidth)x$($Matches.outerHeight)"
    dpi = [int]$Matches.dpi
  }
}

function Invoke-GraphicsCapture {
  param(
    [string] $CaptureTool,
    [IntPtr] $Window,
    [string] $OutputPath,
    [string] $LogPath
  )
  $output = @(& $CaptureTool ([long]$Window) $OutputPath 2>&1)
  $exitCode = $LASTEXITCODE
  $output | Add-Content -LiteralPath $LogPath -Encoding utf8
  if ($exitCode -ne 0) {
    throw "Windows Graphics Capture failed with exit code $exitCode."
  }
  if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
    throw 'Windows Graphics Capture did not create the expected local PNG.'
  }
  $file = Get-Item -LiteralPath $OutputPath
  if ($file.Length -le 0) {
    throw 'Windows Graphics Capture created an empty PNG.'
  }
  $captureLine = @($output | Where-Object { "$_" -match '^CAPTURE_OK ' }) |
    Select-Object -Last 1
  if ($null -eq $captureLine -or "$captureLine" -notmatch '^CAPTURE_OK (?<size>\d+x\d+)$') {
    throw 'Windows Graphics Capture did not report a physical frame size.'
  }
  return [ordered]@{
    physical_frame = $Matches.size
    bytes = $file.Length
  }
}

function Save-WorkflowManifest {
  if ($null -ne $script:workflowManifest -and $null -ne $script:manifestPath) {
    $json = $script:workflowManifest | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText(
      $script:manifestPath,
      $json,
      [System.Text.UTF8Encoding]::new($false)
    )
  }
}

function Invoke-ClientSizeCapture {
  param(
    [int] $Width,
    [int] $Height,
    [string] $CaptureTool,
    [string] $ScreenshotsRoot,
    [string] $RuntimeRoot,
    [string] $LogsRoot
  )

  $label = "${Width}x${Height}"
  $sizeScreenshots = Join-Path $ScreenshotsRoot $label
  $sizeRuntime = Join-Path $RuntimeRoot $label
  New-Item -ItemType Directory -Path $sizeScreenshots, $sizeRuntime | Out-Null

  $sizeRecord = [ordered]@{
    client = $label
    status = 'starting'
    window = $null
    captures = @()
    process_records = @()
    cleanup = $null
  }
  $script:workflowManifest.size_runs += $sizeRecord
  Save-WorkflowManifest

  $process = $null
  $stdoutTask = $null
  $stderrTask = $null
  $records = [System.Collections.ArrayList]::new()
  try {
    $appData = Join-Path $sizeRuntime 'appdata'
    $localAppData = Join-Path $sizeRuntime 'localappdata'
    $webViewData = Join-Path $sizeRuntime 'webview2'
    New-Item -ItemType Directory -Path $appData, $localAppData, $webViewData | Out-Null

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $appPath
    $startInfo.WorkingDirectory = Split-Path -Parent $appPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['APPDATA'] = $appData
    $startInfo.EnvironmentVariables['LOCALAPPDATA'] = $localAppData
    $startInfo.EnvironmentVariables['WEBVIEW2_USER_DATA_FOLDER'] = $webViewData

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
      throw 'Could not start the task application.'
    }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    Update-TaskProcessRecords -RootProcessId $process.Id -Records $records

    $window = Wait-TaskWindow -Process $process
    $sizeRecord.window = Set-VerifiedClientSize -Window $window -Width $Width -Height $Height
    [void](Wait-ForElement -Window $window -AutomationId 'dashboard-home-tab-tasks')
    $renderer = [NativeVisualCaptureDriver]::FindRenderer($window)
    if ($renderer -eq [IntPtr]::Zero) {
      throw 'Could not identify the task application renderer child HWND.'
    }
    Update-TaskProcessRecords -RootProcessId $process.Id -Records $records

    Move-RendererToTop -Renderer $renderer
    Move-RendererToLeft -Renderer $renderer
    Start-Sleep -Milliseconds 700
    $overviewPath = Join-Path $sizeScreenshots 'overview.png'
    $overviewCapture = Invoke-GraphicsCapture `
      -CaptureTool $CaptureTool `
      -Window $window `
      -OutputPath $overviewPath `
      -LogPath (Join-Path $LogsRoot 'graphics-capture.log')
    $sizeRecord.captures += [ordered]@{
      surface = 'Overview'
      selected_tab_visible = $null
      framing = 'page top'
      file = $overviewPath
      physical_frame = $overviewCapture.physical_frame
      bytes = $overviewCapture.bytes
    }
    Save-WorkflowManifest

    foreach ($surface in $surfaces) {
      Move-RendererToTop -Renderer $renderer
      Move-RendererToLeft -Renderer $renderer
      Select-DashboardTab `
        -Window $window `
        -TabId $surface.tab `
        -PanelId $surface.panel
      Move-RendererToLeft -Renderer $renderer
      $framing = Align-DashboardSurface `
        -Window $window `
        -Renderer $renderer `
        -TabId $surface.tab `
        -PanelId $surface.panel
      Move-RendererToLeft -Renderer $renderer
      Start-Sleep -Milliseconds 900
      $outputPath = Join-Path $sizeScreenshots ($surface.slug + '.png')
      $capture = Invoke-GraphicsCapture `
        -CaptureTool $CaptureTool `
        -Window $window `
        -OutputPath $outputPath `
        -LogPath (Join-Path $LogsRoot 'graphics-capture.log')
      $sizeRecord.captures += [ordered]@{
        surface = $surface.name
        selected_tab_visible = $framing.selected_tab_visible
        panel_visible = $framing.panel_visible
        scroll_steps = $framing.scroll_steps
        tab_top_in_client = $framing.tab_top_in_client
        limited_by_page_end = $framing.limited_by_page_end
        file = $outputPath
        physical_frame = $capture.physical_frame
        bytes = $capture.bytes
      }
      Update-TaskProcessRecords -RootProcessId $process.Id -Records $records
      Save-WorkflowManifest
    }
    $sizeRecord.status = 'captured'
  } catch {
    $sizeRecord.status = 'failed'
    $sizeRecord.error = $_.Exception.Message
    throw
  } finally {
    if ($null -ne $process) {
      $sizeRecord.cleanup = Stop-RecordedTaskProcesses `
        -RootProcessId $process.Id `
        -Records $records
      $sizeRecord.process_records = @($records)
      if ($null -ne $stdoutTask) {
        [void]$stdoutTask.Wait(5000)
        if ($stdoutTask.IsCompleted) {
          [System.IO.File]::WriteAllText(
            (Join-Path $LogsRoot "app-$label.stdout.log"),
            $stdoutTask.Result,
            [System.Text.UTF8Encoding]::new($false)
          )
        }
      }
      if ($null -ne $stderrTask) {
        [void]$stderrTask.Wait(5000)
        if ($stderrTask.IsCompleted) {
          [System.IO.File]::WriteAllText(
            (Join-Path $LogsRoot "app-$label.stderr.log"),
            $stderrTask.Result,
            [System.Text.UTF8Encoding]::new($false)
          )
        }
      }
      if ($sizeRecord.cleanup.remaining_matching_process_ids.Count -gt 0) {
        $sizeRecord.status = 'cleanup-failed'
        Save-WorkflowManifest
        throw "Task-owned processes remained after the $label capture."
      }
      if ($sizeRecord.status -eq 'captured') {
        $sizeRecord.status = 'complete'
      }
    }
    Save-WorkflowManifest
  }
}

$resolvedOutputRoot = Get-NormalizedOutputRoot -RequestedPath $OutputRoot
$compiler = Get-CaptureCompiler
$preflight = Get-PreflightManifest `
  -ResolvedOutputRoot $resolvedOutputRoot `
  -Compiler $compiler
Assert-PreflightReady -Preflight $preflight

if ($PreflightOnly) {
  Write-Output (
    'NATIVE_VISUAL_PREFLIGHT=' +
    ($preflight | ConvertTo-Json -Depth 6 -Compress)
  )
  return
}

if (Test-Path -LiteralPath $resolvedOutputRoot) {
  throw "Refusing to overwrite an existing native visual output directory."
}
Test-OutputRootIgnored -ResolvedOutputRoot $resolvedOutputRoot

$screenshotsRoot = Join-Path $resolvedOutputRoot 'screenshots'
$logsRoot = Join-Path $resolvedOutputRoot 'logs'
$runtimeRoot = Join-Path $resolvedOutputRoot 'runtime'
$toolsRoot = Join-Path $resolvedOutputRoot 'tools'
New-Item -ItemType Directory -Path (
  $resolvedOutputRoot,
  $screenshotsRoot,
  $logsRoot,
  $runtimeRoot,
  $toolsRoot
) | Out-Null

$script:manifestPath = Join-Path $resolvedOutputRoot 'manifest.json'
$branch = (& git -C $repositoryRoot branch --show-current).Trim()
$sha = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$script:workflowManifest = [ordered]@{
  status = 'running'
  started_utc = (Get-Date).ToUniversalTime().ToString('o')
  completed_utc = $null
  checkout = [ordered]@{
    branch = $branch
    sha = $sha
  }
  capture_engine = 'Windows.Graphics.Capture'
  targeting = 'exact HWND'
  real_local_codex_input = 'read-only'
  app_runtime_storage = 'task-local under .local-artifacts'
  build = [ordered]@{
    command = $preflight.build_command
    skipped = [bool]$SkipBuild
    result = 'pending'
  }
  size_runs = @()
  screenshot_count = 0
  final_process_cleanup = 'pending'
  error = $null
}
Save-WorkflowManifest

try {
  $existingBeforeBuild = @(Get-ExactExecutableProcesses -ExecutablePath $appPath)
  if ($existingBeforeBuild.Count -gt 0) {
    throw 'The exact target release executable is already running; refusing to manage it.'
  }

  $captureTool = Join-Path $toolsRoot 'GraphicsCaptureSnapshot.exe'
  Build-CaptureHelper `
    -Compiler $compiler `
    -OutputPath $captureTool `
    -LogPath (Join-Path $logsRoot 'capture-helper-build.log')

  if ($SkipBuild) {
    if (-not (Test-Path -LiteralPath $appPath -PathType Leaf)) {
      throw 'SkipBuild was requested but the release executable does not exist.'
    }
    $script:workflowManifest.build.result = 'skipped by explicit switch'
  } else {
    $cargo = Get-Command cargo.exe -ErrorAction SilentlyContinue
    if ($null -eq $cargo) {
      $cargo = Get-Command cargo -ErrorAction Stop
    }
    Invoke-LoggedProcess `
      -FileName $cargo.Source `
      -Arguments @(
        '+stable-x86_64-pc-windows-msvc',
        'tauri',
        'build',
        '--no-bundle'
      ) `
      -WorkingDirectory $windowsRoot `
      -LogPath (Join-Path $logsRoot 'tauri-release-build.log')
    $script:workflowManifest.build.result = 'passed'
  }
  if (-not (Test-Path -LiteralPath $appPath -PathType Leaf)) {
    throw 'The Tauri release build did not create the expected executable.'
  }
  Save-WorkflowManifest

  $existingBeforeLaunch = @(Get-ExactExecutableProcesses -ExecutablePath $appPath)
  if ($existingBeforeLaunch.Count -gt 0) {
    throw 'The exact target release executable became active before capture; refusing to manage it.'
  }

  foreach ($size in $clientSizes) {
    Invoke-ClientSizeCapture `
      -Width $size.width `
      -Height $size.height `
      -CaptureTool $captureTool `
      -ScreenshotsRoot $screenshotsRoot `
      -RuntimeRoot $runtimeRoot `
      -LogsRoot $logsRoot
  }

  $pngFiles = @(
    Get-ChildItem -LiteralPath $screenshotsRoot -Filter '*.png' -File -Recurse
  )
  if ($pngFiles.Count -ne 12) {
    throw "Expected 12 native screenshots, found $($pngFiles.Count)."
  }
  $script:workflowManifest.screenshot_count = $pngFiles.Count

  $remainingExactApp = @(Get-ExactExecutableProcesses -ExecutablePath $appPath)
  $remainingOwned = @(
    $script:workflowManifest.size_runs |
      ForEach-Object { @($_.cleanup.remaining_matching_process_ids) }
  )
  if ($remainingExactApp.Count -ne 0 -or $remainingOwned.Count -ne 0) {
    throw 'Task app or recorded task-owned WebView2 processes remained after capture.'
  }

  $script:workflowManifest.final_process_cleanup = 'confirmed'
  $script:workflowManifest.status = 'complete'
} catch {
  $script:workflowManifest.status = 'failed'
  $script:workflowManifest.error = $_.Exception.Message
  throw
} finally {
  $script:workflowManifest.completed_utc = (Get-Date).ToUniversalTime().ToString('o')
  Save-WorkflowManifest
}

$summary = [ordered]@{
  status = $script:workflowManifest.status
  screenshots = $script:workflowManifest.screenshot_count
  client_sizes = @($preflight.client_sizes)
  surfaces = @($preflight.surfaces)
  process_cleanup = $script:workflowManifest.final_process_cleanup
  output_root = $resolvedOutputRoot
}
Write-Output (
  'NATIVE_VISUAL_CAPTURE_COMPLETE=' +
  ($summary | ConvertTo-Json -Depth 5 -Compress)
)
