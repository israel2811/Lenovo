$ErrorActionPreference = 'Stop'

# 1. FIX PATH
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
if ($machinePath -notmatch '(?i)(^|;)C:\\Windows\\System32(;|$)') {
    $newMachinePath = "C:\Windows\System32;$machinePath"
    [Environment]::SetEnvironmentVariable('Path', $newMachinePath, 'Machine')
    Write-Host "Fixed Machine PATH by prepending C:\Windows\System32"
}

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notmatch '(?i)(^|;)C:\\Windows\\System32(;|$)') {
    $newUserPath = "C:\Windows\System32;$userPath"
    [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
}
$env:Path = "C:\Windows\System32;" + $env:Path

# 2. INCREASE PAGEFILE
$sys = Get-CimInstance Win32_ComputerSystem
if ($sys.AutomaticManagedPagefile) {
    Set-CimInstance -InputObject $sys -Property @{AutomaticManagedPagefile=$false}
}
$pagefiles = Get-CimInstance Win32_PageFileSetting
if ($pagefiles) {
    foreach ($pf in $pagefiles) {
        if ($pf.InitialSize -lt 6144) {
            Set-CimInstance -InputObject $pf -Property @{InitialSize=6144; MaximumSize=8192}
            Write-Host "Increased PageFile $($pf.Name) to 6GB-8GB. Reboot required."
        }
    }
} else {
    New-CimInstance -ClassName Win32_PageFileSetting -Property @{Name="C:\pagefile.sys"; InitialSize=6144; MaximumSize=8192}
    Write-Host "Set new PageFile to 6GB-8GB. Reboot required."
}

# 3. REDACT SECRETS IN BACKUPS
$configPath = "C:\Users\Lenovo\.gemini\antigravity\mcp_config_backup_latest.json"
if (Test-Path $configPath) {
    $content = Get-Content $configPath -Raw
    if ($content -match 'X-Goog-Api-Key: [A-Za-z0-9_\-]+') {
        $content = $content -replace 'X-Goog-Api-Key: [A-Za-z0-9_\-]+', 'X-Goog-Api-Key: [REDACTED]'
        Set-Content -Path $configPath -Value $content -Encoding UTF8
        Write-Host "Redacted API key in mcp_config_backup_latest.json"
    }
}

# 4. KILL MEMORY HOGS (excluding current Antigravity)
Stop-Process -Name Dropbox -Force -ErrorAction SilentlyContinue
# Stop-Process -Name chrome -Force -ErrorAction SilentlyContinue

Write-Host "Remediation Script Complete."
