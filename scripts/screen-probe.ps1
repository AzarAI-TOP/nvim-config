# Screen probe for the statusline narrow-layout threshold.
# Takes the calling nvim's PID, resolves its parent process (the Neovide
# instance that embedded it), and prints "<screen width> <client width>" on
# one line. The screen is the one the window actually sits on (a secondary
# monitor can differ from the primary), and the width is the client area
# (grid + Neovide padding, without borders), so pixels-per-column is
# computed from the same window whose column count the Lua side divides by.
# Outputs "<primary width> 0" when the ancestry chain breaks (e.g. a
# standalone run without -NvimPid); the statusline module rejects 0 and
# keeps its cached/default threshold.
param([int]$NvimPid)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public struct RECT { public int Left, Top, Right, Bottom; }
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT rect);
}
'@

# neovide.exe spawns the embedded nvim.exe as its child, so nvim's parent is
# this instance's window owner. Matching by ancestry instead of "first
# neovide process found" keeps the measurement correct with several
# instances of different sizes open at once.
$parentPid = (Get-CimInstance Win32_Process -Filter "ProcessId=$NvimPid").ParentProcessId
$neovide = if ($parentPid) { Get-Process -Id $parentPid -ErrorAction SilentlyContinue } else { $null }

if ($neovide -and $neovide.ProcessName -eq "neovide" -and $neovide.MainWindowHandle -ne 0) {
    $rect = New-Object RECT
    [Win32]::GetClientRect($neovide.MainWindowHandle, [ref]$rect) | Out-Null
    $screenWidth = [System.Windows.Forms.Screen]::FromHandle($neovide.MainWindowHandle).Bounds.Width
    Write-Output "$screenWidth $($rect.Right - $rect.Left)"
} else {
    Write-Output "$([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width) 0"
}
