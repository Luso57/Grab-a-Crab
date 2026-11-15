param([string]$Action = 'inspect')
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CrabPreviewWindow {
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
}
'@
$studioProcess = Get-Process RobloxStudioBeta | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $studioProcess) { throw 'No visible Studio window.' }
$rootElement = [System.Windows.Automation.AutomationElement]::FromHandle($studioProcess.MainWindowHandle)
if ($Action -eq 'clearpreviewqueue') {
    $wshell = New-Object -ComObject WScript.Shell
    $null=$wshell.AppActivate([int]$studioProcess.Id)
    Start-Sleep -Milliseconds 200
    if ([CrabPreviewWindow]::GetForegroundWindow() -ne $studioProcess.MainWindowHandle) { throw 'Studio not foreground.' }
    $r=$rootElement.Current.BoundingRectangle
    # The preceding screenshot shows one queue row: our unimported LavaCrab.
    [CrabPreviewWindow]::SetCursorPos([int]($r.X+52),[int]($r.Y+489)) | Out-Null
    [CrabPreviewWindow]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
    [CrabPreviewWindow]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 300
}
if ($Action -eq 'choosefile') {
    $condition = New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::NameProperty), 'Open 3D File (FBX, OBJ, GLB, GLTF)'
    $dialog=$rootElement.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$condition)
    if (-not $dialog) { throw 'Expected Studio file chooser is not open.' }
    $dialog.SetFocus()
    [System.Windows.Forms.SendKeys]::SendWait('%n')
    [System.Windows.Forms.SendKeys]::SendWait('^a')
    [System.Windows.Forms.SendKeys]::SendWait('C:\Grab a Crab\Crabmodels\LavaCrab.fbx')
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    Start-Sleep -Milliseconds 1600
}
if ($Action -eq 'openimport') {
    $wshell = New-Object -ComObject WScript.Shell
    $null=$wshell.AppActivate([int]$studioProcess.Id)
    Start-Sleep -Milliseconds 200
    if ([CrabPreviewWindow]::GetForegroundWindow() -ne $studioProcess.MainWindowHandle) { throw 'Studio not foreground.' }
    $r=$rootElement.Current.BoundingRectangle
    [CrabPreviewWindow]::SetCursorPos([int]($r.X+751),[int]($r.Y+80)) | Out-Null
    [CrabPreviewWindow]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
    [CrabPreviewWindow]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 600
}
if ($Action -eq 'activate') {
    [CrabPreviewWindow]::ShowWindow($studioProcess.MainWindowHandle, 9) | Out-Null
    $wshell = New-Object -ComObject WScript.Shell
    $active=$wshell.AppActivate([int]$studioProcess.Id)
    Start-Sleep -Milliseconds 600
    Write-Output "AppActivate: $active; foreground: $([CrabPreviewWindow]::GetForegroundWindow()); studio: $($studioProcess.MainWindowHandle)"
}
if ($Action -eq 'filemenu') {
    [CrabPreviewWindow]::SetForegroundWindow($studioProcess.MainWindowHandle) | Out-Null
    $condition = New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::NameProperty), 'File'
    $file = $rootElement.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
    if (-not $file) { throw 'File menu not found.' }
    $patterns=$file.GetSupportedPatterns()
    Write-Output ($patterns | ForEach-Object { $_.ProgrammaticName })
    $invoke=$null
    if ($file.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$invoke)) { $invoke.Invoke() }
    else { [System.Windows.Forms.SendKeys]::SendWait('%f') }
    Start-Sleep -Milliseconds 400
}
if ($Action -eq 'escape') {
    [CrabPreviewWindow]::SetForegroundWindow($studioProcess.MainWindowHandle) | Out-Null
    [System.Windows.Forms.SendKeys]::SendWait('{ESC}')
    Start-Sleep -Milliseconds 200
}
$elements = $rootElement.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
for ($i=0; $i -lt $elements.Count; $i++) {
    $e=$elements.Item($i)
    if ($e.Current.Name) {
        Write-Output "$($e.Current.ControlType.ProgrammaticName) | $($e.Current.Name) | $($e.Current.BoundingRectangle)"
    }
}
$rect=$rootElement.Current.BoundingRectangle
$bmp=New-Object System.Drawing.Bitmap ([int]$rect.Width), ([int]$rect.Height)
$graphics=[System.Drawing.Graphics]::FromImage($bmp)
$graphics.CopyFromScreen([int]$rect.X,[int]$rect.Y,0,0,$bmp.Size)
$bmp.Save('C:\Grab a Crab\artifacts\crab-variants\StudioPreviewCheck.png',[System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bmp.Dispose()
