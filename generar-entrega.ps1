<#
.SYNOPSIS
  Genera el archivo .zip de entrega del Taller de API REST cumpliendo con los requisitos de entrega.
.DESCRIPTION
  Empaqueta el código fuente, schema SQL, colecciones de Postman, scripts y PDF de evidencias,
  excluyendo explícitamente "node_modules" y el archivo ".env" con secretos locales.
.PARAMETER Apellido
  Apellido del estudiante (ej: Perez)
.PARAMETER Nombre
  Nombre del estudiante (ej: Juan)
#>
param(
    [string]$Apellido = "Apellido",
    [string]$Nombre = "Nombre"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$raiz = $PSScriptRoot
$origen = Join-Path $raiz "Taller_API_Apellido_Nombre"
if (-not (Test-Path $origen)) {
    $origen = $raiz
}

$nombreFinal = "Taller_API_${Apellido}_${Nombre}"
$zipSalida = Join-Path $raiz "$nombreFinal.zip"
$tempDir = Join-Path $env:TEMP $nombreFinal

Write-Host "==> Preparando entrega: $nombreFinal" -ForegroundColor Cyan

if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
if (Test-Path $zipSalida) { Remove-Item -Force $zipSalida }

New-Item -ItemType Directory -Path $tempDir | Out-Null

# Copiar archivos excluyendo node_modules, .env y logs
Get-ChildItem -Path $origen -Exclude "node_modules", ".env", "*.log" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $tempDir -Recurse -Force
}

# Comprimir
Write-Host "==> Creando archivo ZIP..." -ForegroundColor Cyan
Compress-Archive -Path "$tempDir\*" -DestinationPath $zipSalida -Force

# Limpiar temporal
Remove-Item -Recurse -Force $tempDir

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " ¡Entrega empaquetada con exito!" -ForegroundColor Green
Write-Host " Archivo generado: $zipSalida" -ForegroundColor Yellow
Write-Host " Tamano: $([math]::Round((Get-Item $zipSalida).Length / 1KB, 2)) KB" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
