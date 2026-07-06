Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 1. Get current script/exe directory
$baseDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($baseDir)) {
    $baseDir = [System.IO.Path]::GetDirectoryName([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
}

function Start-App {
    param([string]$exePath, [string]$workDir)
    if (Test-Path $exePath) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exePath
        $psi.WorkingDirectory = $workDir
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $psi.CreateNoWindow = $true
        $psi.UseShellExecute = $false
        return [System.Diagnostics.Process]::Start($psi)
    } else {
        [System.Windows.Forms.MessageBox]::Show("File not found: $exePath", "Startup Error")
        return $null
    }
}

# ==================== 2. Dynamic Search & Start ====================
# Search for cli-proxy-api.exe in all subfolders dynamically
$cliFile = Get-ChildItem -Path $baseDir -Filter "cli-proxy-api.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if ($null -ne $cliFile) {
    $global:proc1 = Start-App -exePath $cliFile.FullName -workDir $cliFile.DirectoryName
} else {
    [System.Windows.Forms.MessageBox]::Show("Cannot find 'cli-proxy-api.exe' in any subfolder.", "Error")
}

# Search for cpa-manager-plus.exe in all subfolders dynamically
$cpaFile = Get-ChildItem -Path $baseDir -Filter "cpa-manager-plus.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if ($null -ne $cpaFile) {
    $global:proc2 = Start-App -exePath $cpaFile.FullName -workDir $cpaFile.DirectoryName
} else {
    [System.Windows.Forms.MessageBox]::Show("Cannot find 'cpa-manager-plus.exe' in any subfolder.", "Error")
}

# ==================== 3. Open Browser ====================
Start-Sleep -Seconds 2
Start-Process "http://localhost:18317" -ErrorAction SilentlyContinue


# ==================== 4. System Tray Icon Setup ====================
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon

# Load custom icon: cpa.ico
$iconPath = Join-Path $baseDir "cpa.ico"
if (Test-Path $iconPath) {
    $notifyIcon.Icon = New-Object System.Drawing.Icon($iconPath)
} else {
    # Fallback to system icon if cpa.ico is missing
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Warning
    [System.Windows.Forms.MessageBox]::Show("Icon 'cpa.ico' not found. Using default icon.", "Warning")
}

$notifyIcon.Text = "CPA Services Running"
$notifyIcon.Visible = $true

# Create Context Menu
$menu = New-Object System.Windows.Forms.ContextMenu

# Open Home Page menu item
$homeItem = New-Object System.Windows.Forms.MenuItem
$homeItem.Text = "Open Home Page"
$homeItem.add_Click({
    Start-Process "http://localhost:18317" -ErrorAction SilentlyContinue
})
[void]$menu.MenuItems.Add($homeItem)

# Menu separator
$separatorItem = New-Object System.Windows.Forms.MenuItem
$separatorItem.Text = "-"
[void]$menu.MenuItems.Add($separatorItem)

# Exit menu item
$exitItem = New-Object System.Windows.Forms.MenuItem
$exitItem.Text = "Exit CPA Services"

# Exit click event
$exitItem.add_Click({
    $notifyIcon.Visible = $false
    
    # 1. Kill tracked process objects
    if ($global:proc1 -and -not $global:proc1.HasExited) { $global:proc1.Kill() }
    if ($global:proc2 -and -not $global:proc2.HasExited) { $global:proc2.Kill() }

    # 2. Force tree kill via cmd for any leftovers/child processes
    $killCmd = "/c taskkill /F /IM cli-proxy-api.exe /T >nul 2>&1 & taskkill /F /IM cpa-manager-plus.exe /T >nul 2>&1"
    $psiKill = New-Object System.Diagnostics.ProcessStartInfo
    $psiKill.FileName = "cmd.exe"
    $psiKill.Arguments = $killCmd
    $psiKill.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $psiKill.CreateNoWindow = $true
    [System.Diagnostics.Process]::Start($psiKill) | Out-Null

    [System.Windows.Forms.Application]::Exit()
})

[void]$menu.MenuItems.Add($exitItem)
$notifyIcon.ContextMenu = $menu

# Run application loop
[System.Windows.Forms.Application]::Run()