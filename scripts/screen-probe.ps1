# Screen probe for the statusline narrow-layout threshold.
# Prints "<primary screen width> <Neovide window width>" on one line; the
# statusline module (lua/plugins/statusline.lua) spawns this via jobstart and
# derives pixels-per-column from the pair. Outputs "<width> 0" when no Neovide
# window exists yet.
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
$neovide = Get-Process neovide -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } |
    Select-Object -First 1

if ($neovide) {
    $rect = New-Object RECT
    [Win32]::GetWindowRect($neovide.MainWindowHandle, [ref]$rect) | Out-Null
    Write-Output "$screenWidth $($rect.Right - $rect.Left)"
} else {
    Write-Output "$screenWidth 0"
}
