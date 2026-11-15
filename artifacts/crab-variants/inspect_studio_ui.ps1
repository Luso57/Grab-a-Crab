Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$studioProcess = Get-Process RobloxStudioBeta | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $studioProcess) { throw 'No visible Studio window.' }
$rootElement = [System.Windows.Automation.AutomationElement]::FromHandle($studioProcess.MainWindowHandle)
$elements = $rootElement.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
Write-Output "Window: $($rootElement.Current.Name)"
Write-Output "Bounds: $($rootElement.Current.BoundingRectangle)"
for ($i=0; $i -lt $elements.Count; $i++) {
    $e=$elements.Item($i)
    if ($e.Current.Name -and $e.Current.Name -match 'File|Import|Home|Menu|Browse|Cancel|Open|Lava|Crabmodels') {
        Write-Output "$($e.Current.ControlType.ProgrammaticName) | $($e.Current.Name) | $($e.Current.AutomationId) | $($e.Current.BoundingRectangle)"
    }
}
