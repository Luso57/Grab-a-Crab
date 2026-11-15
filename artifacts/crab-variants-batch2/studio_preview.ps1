param([ValidateSet('inspect','open','choose','close','filter','rowmenu','removeentry','resetfilter')][string]$Action='inspect')
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CrabBatch2Window {
 public delegate bool EnumWindowProc(IntPtr hWnd,IntPtr data);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowProc proc,IntPtr data);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
 [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr hWnd,uint flags);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd,System.Text.StringBuilder text,int count);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint dx,uint dy,uint data,UIntPtr extra);
 public static IntPtr FindStudioWindow(uint pid) {
   IntPtr result=IntPtr.Zero;
   EnumWindows((h,d)=>{
     uint owner;GetWindowThreadProcessId(h,out owner);
     if(owner==pid) {
       var text=new System.Text.StringBuilder(512);GetWindowText(h,text,512);
       if(text.ToString().Contains("Grab a Crab") && text.ToString().Contains("Roblox Studio")) result=h;
     }
     return true;
   },IntPtr.Zero);
   return result;
 }
}
'@
$studio=$null
foreach ($candidate in @(Get-Process RobloxStudioBeta)) {
    $handle=[CrabBatch2Window]::FindStudioWindow([uint32]$candidate.Id)
    $caption=New-Object System.Text.StringBuilder 512
    $null=[CrabBatch2Window]::GetWindowText($handle,$caption,512)
    if ($handle -ne [IntPtr]::Zero) {
        $studio=[pscustomobject]@{ Id=$candidate.Id; MainWindowHandle=$handle }
        break
    }
}
if (-not $studio) { throw 'Expected Grab a Crab Studio window was not found.' }
if ($true) {
    [CrabBatch2Window]::ShowWindow($studio.MainWindowHandle,9) | Out-Null
    $shell=New-Object -ComObject WScript.Shell
    $null=$shell.AppActivate([int]$studio.Id)
    Start-Sleep -Milliseconds 400
}
[uint32]$foregroundProcess=0
$null=[CrabBatch2Window]::GetWindowThreadProcessId([CrabBatch2Window]::GetForegroundWindow(),[ref]$foregroundProcess)
if ($foregroundProcess -ne $studio.Id) { throw 'Studio is not in the foreground.' }
$root=[System.Windows.Automation.AutomationElement]::FromHandle($studio.MainWindowHandle)
function Find-Named([string]$name) {
    $condition=New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::NameProperty),$name
    return $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$condition)
}
if ($Action -eq 'open') {
    if ((Find-Named 'Import Preview') -or (Find-Named 'Open 3D File (FBX, OBJ, GLB, GLTF)')) { throw 'An import dialog is already open.' }
    [System.Windows.Forms.SendKeys]::SendWait('^m')
    Start-Sleep -Milliseconds 700
}
if ($Action -eq 'choose') {
    if (-not (Find-Named 'Open 3D File (FBX, OBJ, GLB, GLTF)')) { throw 'The expected file chooser is not open.' }
    [System.Windows.Forms.SendKeys]::SendWait('%n')
    [System.Windows.Forms.SendKeys]::SendWait('^a')
    [System.Windows.Forms.SendKeys]::SendWait('C:\Grab a Crab\Crabmodels\SushiCrab.fbx')
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    Start-Sleep -Milliseconds 1800
}
if ($Action -eq 'close') {
    if (-not (Find-Named 'Import Preview')) { throw 'Import Preview is not open.' }
    [System.Windows.Forms.SendKeys]::SendWait('{ESC}')
    Start-Sleep -Milliseconds 300
}
if ($Action -in @('filter','resetfilter','rowmenu','removeentry')) {
    if (Find-Named 'Import Preview') { throw 'Close the preview first.' }
    $rect=$root.Current.BoundingRectangle
    if ($rect.Width -ne 1676) { throw 'Studio layout changed; inspect before clicking.' }
    if ($Action -eq 'removeentry') {
        # Restore the observed context menu in this same foreground interaction.
        [System.Windows.Forms.SendKeys]::SendWait('{ESC}')
        [CrabBatch2Window]::SetCursorPos([int]($rect.X+750),[int]($rect.Y+869)) | Out-Null
        [CrabBatch2Window]::mouse_event(8,0,0,0,[UIntPtr]::Zero)
        [CrabBatch2Window]::mouse_event(16,0,0,0,[UIntPtr]::Zero)
        Start-Sleep -Milliseconds 300
        # Observed context menu: Delete from queue for the filtered SushiCrab row.
        [CrabBatch2Window]::SetCursorPos([int]($rect.X+828),[int]($rect.Y+903)) | Out-Null
        [CrabBatch2Window]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
        [CrabBatch2Window]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
    } elseif ($Action -eq 'rowmenu') {
        [CrabBatch2Window]::SetCursorPos([int]($rect.X+750),[int]($rect.Y+869)) | Out-Null
        [CrabBatch2Window]::mouse_event(8,0,0,0,[UIntPtr]::Zero)
        [CrabBatch2Window]::mouse_event(16,0,0,0,[UIntPtr]::Zero)
    } else {
        [CrabBatch2Window]::SetCursorPos([int]($rect.X+900),[int]($rect.Y+813)) | Out-Null
        [CrabBatch2Window]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
        [CrabBatch2Window]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
        [System.Windows.Forms.SendKeys]::SendWait('^a')
        if ($Action -eq 'filter') { [System.Windows.Forms.SendKeys]::SendWait('SushiCrab') }
        else { [System.Windows.Forms.SendKeys]::SendWait('{BACKSPACE}') }
    }
    Start-Sleep -Milliseconds 500
}
$elements=$root.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
for ($i=0;$i -lt $elements.Count;$i++) {
    $e=$elements.Item($i)
    if ($e.Current.Name -and ($e.Current.Name -match 'Import|Open|Close|Sushi|Cancel|File name')) {
        Write-Output "$($e.Current.ControlType.ProgrammaticName) | $($e.Current.Name) | $($e.Current.BoundingRectangle)"
    }
}
$rect=$root.Current.BoundingRectangle
$bitmap=New-Object System.Drawing.Bitmap ([int]$rect.Width),([int]$rect.Height)
$graphics=[System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen([int]$rect.X,[int]$rect.Y,0,0,$bitmap.Size)
$bitmap.Save('C:\Grab a Crab\artifacts\crab-variants-batch2\StudioPreviewCheck.png',[System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose();$bitmap.Dispose()
