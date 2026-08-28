# Screen probe for the statusline narrow-layout threshold.
# Takes the calling nvim's PID, resolves its parent process (the Neovide
# instance that embedded it), and prints "<primary screen width> <that
# window's width>" on one line: pixels-per-column must come from the same
# window whose column count the Lua side divides by. Outputs "<width> 0"
# when the ancestry chain breaks (e.g. run standalone without -NvimPid);
# the statusline module rejects 0 and keeps its cached/default threshold.
param([int]$NvimPid)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public struct RECT { public int Left, Top, Right, Bottom; }
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
}
'@

$screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width

# neovide.exe spawns the embedded nvim.exe as its child, so nvim's parent is
# this instance's window owner. Matching by ancestry instead of "first
# neovide process found" keeps the measurement correct with several
# instances of different sizes open at once.
$parentPid = (Get-CimInstance Win32_Process -Filter "ProcessId=$NvimPid").ParentProcessId
$neovide = if ($parentPid) { Get-Process -Id $parentPid -ErrorAction SilentlyContinue } else { $null }

if ($neovide -and $neovide.ProcessName -eq "neovide" -and $neovide.MainWindowHandle -ne 0) {
    $rect = New-Object RECT
    [Win32]::GetWindowRect($neovide.MainWindowHandle, [ref]$rect) | Out-Null
    Write-Output "$screenWidth $($rect.Right - $rect.Left)"
} else {
    Write-Output "$screenWidth 0"
}
