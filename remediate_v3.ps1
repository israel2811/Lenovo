$ErrorActionPreference = 'Stop'

Write-Host "INICIANDO CONTENCION Y REPARACION..."

# 1. Configurar NODE_OPTIONS para limitar consumo de RAM (4GB max -> 512MB limit node)
[Environment]::SetEnvironmentVariable("NODE_OPTIONS", "--max-old-space-size=512", "User")
$env:NODE_OPTIONS = "--max-old-space-size=512"
Write-Host "NODE_OPTIONS limitados a 512MB."

# 2. Reparar PATH en el Sistema y Sesion
$MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$Sys32 = "C:\Windows\System32"

if ($MachinePath -notmatch [regex]::Escape($Sys32)) {
    $NewMachinePath = "$Sys32;C:\Windows;C:\Windows\System32\Wbem;$MachinePath"
    [Environment]::SetEnvironmentVariable("Path", $NewMachinePath, "Machine")
    Write-Host "PATH de Maquina corregido."
}

if ($env:PATH -notmatch [regex]::Escape($Sys32)) {
    $env:PATH = "$Sys32;C:\Windows;C:\Windows\System32\Wbem;$env:PATH"
    Write-Host "PATH de sesion corregido."
}

# 3. Ampliar Pagefile de forma segura
try {
    # Eliminar manejo automatico
    $cs = Get-CimInstance Win32_ComputerSystem
    if ($cs.AutomaticManagedPagefile) {
        Set-CimInstance -Query "Select * from Win32_ComputerSystem" -Property @{AutomaticManagedPagefile=$False}
    }
    
    # Set pagefile to 2048 - 4096
    $pf = Get-CimInstance Win32_PageFileSetting -Filter "Name='C:\\pagefile.sys'"
    if ($pf) {
        Invoke-CimMethod -InputObject $pf -MethodName set -Arguments @{InitialSize=2048; MaximumSize=4096} | Out-Null
        Write-Host "Pagefile configurado a 2048-4096 MB."
    }
} catch {
    Write-Host "No se pudo cambiar el pagefile: $_"
}

# 4. Backup y Validacion de Config de Antigravity
$AppDir = "C:\Users\Lenovo\.gemini\antigravity"
$NexusDir = "C:\ANTIGRAVITY_NEXUS"

if (-not (Test-Path $NexusDir)) { New-Item -Path $NexusDir -ItemType Directory -Force | Out-Null }

$TargetConfig = "$AppDir\mcp_config.json"
if (Test-Path $TargetConfig) {
    $Timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    Copy-Item $TargetConfig -Destination "$NexusDir\mcp_config_backup_$Timestamp.json" -Force
    Write-Host "Config respaldada en Nexus."
}

# 5. Escribir Core Config (Core Estable)
$CoreConfig = @{
    mcpServers = @{
        filesystem = @{
            command = "C:\nvm4w\nodejs\npx.cmd"
            args = @("-y", "@modelcontextprotocol/server-filesystem", "C:\Lenovo", "C:\ANTIGRAVITY_NEXUS")
            env = @{}
        }
    }
}
$JsonOut = $CoreConfig | ConvertTo-Json -Depth 5
$JsonOut | Set-Content -Path $TargetConfig -Encoding UTF8
Write-Host "Perfil Core Estable configurado."

Write-Host "=== REPARACION COMPLETADA ==="
