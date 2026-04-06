param (
    [Parameter(Mandatory=$true)]
    [string]$TargetToken,

    [Parameter(Mandatory=$false)]
    [string]$SourceToken = ""
)

$SourceUser = "israel2811"
$TargetUser = "israelrealivazquez-lang"

Write-Host "Iniciando migración de repositorios de $SourceUser a $TargetUser..." -ForegroundColor Cyan

# Headers for API
$TargetHeaders = @{
    "Authorization" = "token $TargetToken"
    "Accept" = "application/vnd.github.v3+json"
}

$SourceHeaders = @{
    "Accept" = "application/vnd.github.v3+json"
}
if ($SourceToken -ne "") {
    $SourceHeaders["Authorization"] = "token $SourceToken"
}

# 1. Obtener repositorios
Write-Host "1. Obteniendo lista de repositorios..." -ForegroundColor Yellow
$Repos = @()
$Page = 1

try {
    if ($SourceToken -ne "") {
        # Si hay token de origen, podemos obtener también los privados
        $Url = "https://api.github.com/user/repos?visibility=all&per_page=100&page=$Page"
    } else {
        # Solo públicos
        $Url = "https://api.github.com/users/$SourceUser/repos?per_page=100&page=$Page"
    }
    
    do {
        $Response = Invoke-RestMethod -Uri $Url -Headers $SourceHeaders -Method Get
        
        # Filtrar solo los que pertenecen a $SourceUser y no son forks (opcional, aquí incluimos todos los propios)
        $UserRepos = $Response | Where-Object { $_.owner.login -eq $SourceUser }
        $Repos += $UserRepos
        
        $Page++
        if ($SourceToken -ne "") {
            $Url = "https://api.github.com/user/repos?visibility=all&per_page=100&page=$Page"
        } else {
            $Url = "https://api.github.com/users/$SourceUser/repos?per_page=100&page=$Page"
        }
    } while ($Response.Count -eq 100)
    
} catch {
    Write-Error "Error obteniendo repositorios: $_"
    exit
}

Write-Host ("Se encontraron " + $Repos.Count + " repositorios.") -ForegroundColor Green

# 2. Migrar cada repositorio
$TempDir = "C:\Lenovo\temp_repo_migration"
if (!(Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir | Out-Null }
Set-Location $TempDir

foreach ($Repo in $Repos) {
    Write-Host "----------------------------------------"
    Write-Host "Migrando: $($Repo.name)..." -ForegroundColor Yellow
    
    # Crear repo en destino
    $CreateUrl = "https://api.github.com/user/repos"
    $Body = @{
        name = $Repo.name
        description = $Repo.description
        private = $Repo.private
    } | ConvertTo-Json
    
    try {
        Write-Host "  -> Creando repositorio vacío en $TargetUser..."
        $CreateResponse = Invoke-RestMethod -Uri $CreateUrl -Headers $TargetHeaders -Method Post -Body $Body -ContentType "application/json"
    } catch {
        $ErrorMsg = $_.Exception.Message
        if ($ErrorMsg -match "422") {
            Write-Host "  -> El repositorio ya existe en el destino, continuando..." -ForegroundColor DarkYellow
        } else {
            Write-Error "  -> Error creando repo: $_"
            continue
        }
    }

    # Clonar
    $RepoName = $Repo.name
    $CloneUrl = $Repo.clone_url
    if ($Repo.private -eq $true -and $SourceToken -ne "") {
        # Insertar token en URL
        $CloneUrl = $CloneUrl -replace "https://", "https://$SourceToken@"
    }
    
    Write-Host "  -> Clonando repositorio (bare)..."
    git clone --bare $CloneUrl
    
    if (Test-Path "$RepoName.git") {
        Set-Location "$RepoName.git"
        
        $TargetRepoUrl = "https://$TargetToken@github.com/$TargetUser/$RepoName.git"
        Write-Host "  -> Empujando a destino (mirror)..."
        git push --mirror $TargetRepoUrl
        
        Set-Location $TempDir
        Write-Host "  -> Limpiando temporal..."
        Remove-Item "$RepoName.git" -Recurse -Force
        
        Write-Host "  -> ¡Migrado con éxito!" -ForegroundColor Green
    } else {
        Write-Error "  -> No se pudo clonar $RepoName"
    }
}

Set-Location "C:\Lenovo"
Remove-Item $TempDir -Recurse -Force | Out-Null
Write-Host "----------------------------------------"
Write-Host "¡MIGRACIÓN COMPLETA!" -ForegroundColor Cyan
