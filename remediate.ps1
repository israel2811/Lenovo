$ErrorActionPreference = 'Stop'
$NexusDir = "C:\ANTIGRAVITY_NEXUS"
$ConfigDir = "$env:USERPROFILE\.gemini\antigravity"

# 1. Create Nexus
New-Item -Path $NexusDir -ItemType Directory -Force | Out-Null
Write-Host "Nexus created at $NexusDir"

# 2. Backup
$Timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
Get-ChildItem "$ConfigDir\mcp_config*" | ForEach-Object {
    Copy-Item $_.FullName -Destination "$NexusDir\$($_.Name)_backup_$Timestamp" -Force
    Write-Host "Backed up $($_.Name)"
}

# 3. Write Core Config
$CoreConfig = @{
    mcpServers = @{
        filesystem = @{
            command = "C:\nvm4w\nodejs\npx.cmd"
            args = @("-y", "@modelcontextprotocol/server-filesystem", "C:\Lenovo", "C:\ANTIGRAVITY_NEXUS")
            env = @{}
        }
    }
}

$JsonContent = $CoreConfig | ConvertTo-Json -Depth 5
$JsonContent | Set-Content -Path "$ConfigDir\mcp_config.json" -Encoding UTF8
Write-Host "Core stable config applied."

# 4. Cleanup Path
$PathParts = $env:PATH -split ';' | Where-Object { $_.Trim() -ne '' }
$HasSystem32 = $false
foreach ($part in $PathParts) {
    if ($part -eq 'C:\Windows\System32' -or $part -eq 'C:\Windows\System32\') {
        $HasSystem32 = $true
    }
}
if (-not $HasSystem32) {
    $env:PATH = "C:\Windows\System32;C:\Windows;C:\Windows\System32\Wbem;" + $env:PATH
    Write-Host "Fixed active session PATH."
}

Write-Host "Remediation complete."
