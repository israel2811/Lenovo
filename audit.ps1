$audit = @{}
$audit.OS = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture, TotalVisibleMemorySize, FreePhysicalMemory, TotalVirtualMemorySize, FreeVirtualMemory, SizeStoredInPagingFiles
$audit.Processes = Get-Process | Sort-Object -Property WorkingSet -Descending | Select-Object -First 15 Name, Id, WorkingSet, PagedMemorySize
$audit.Path = $env:PATH -split ';'

$audit.Tools = @{}
$tools = @("node", "npm", "npx", "npx.cmd", "go", "git", "python", "nvm")
foreach ($t in $tools) {
    $cmd = Get-Command $t -ErrorAction SilentlyContinue
    if ($cmd) { 
        $audit.Tools[$t] = $cmd.Source 
    } else { 
        $audit.Tools[$t] = $null 
    }
}

$audit.Env = @{
    NODE_OPTIONS = $env:NODE_OPTIONS
}
$audit.Browsers = Get-Process | Where-Object { $_.Name -match "chrome|edge|msedge|webview" } | Select-Object Name, Id, WorkingSet

$audit | ConvertTo-Json -Depth 4 | Out-File "$env:TEMP\audit_report.json" -Encoding utf8
