# ============================================================
# DC01 - PARTE 1: Instalar Active Directory y promover a DC
# ============================================================
# Explicación: Este script se ejecuta la primera vez que arranca la maquina
# (lo lanza el UserData del CloudFormation). Instala el rol AD DS, programa
# la Parte 2 para que se ejecute sola tras el reinicio, y promueve esta
# maquina a Controlador de Dominio (lo que provoca un reinicio automatico).
# ============================================================

# Explicación: Si el script ya se ejecuto antes existe este fichero en C:\
# y salimos para evitar que se vuelva a lanzar en reinicios futuros.
if (Test-Path "C:\AD_PARTE1_COMPLETADA.txt") {
    Write-Host "Parte 1 ya ejecutada anteriormente. Saliendo." -ForegroundColor Yellow
    exit
}

Write-Host "=== PARTE 1: Instalando Active Directory ===" -ForegroundColor Cyan

# --- Instalar rol AD DS ---
# Explicación: AD DS (Active Directory Domain Services) es el rol que convierte
# Windows Server en un servidor de dominio capaz de gestionar usuarios, equipos
# y politicas. -IncludeManagementTools instala tambien las herramientas graficas.
Write-Host "[1/3] Instalando rol AD-Domain-Services..." -ForegroundColor Yellow
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
Write-Host "Rol instalado correctamente." -ForegroundColor Green

# --- Crear tarea programada ---
# Explicación: Al promover el servidor a DC (paso 3), Windows se reinicia solo.
# Por eso creamos una tarea que ejecuta la Parte 2 al arrancar el sistema,
# sin necesitar que nadie inicie sesion manualmente.
Write-Host "[2/3] Programando tarea automatica para Parte 2..." -ForegroundColor Yellow

$action   = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-ExecutionPolicy Bypass -File C:\DC01_Parte2_Configurar.ps1"
$trigger  = New-ScheduledTaskTrigger -AtStartup    # se dispara al arrancar, no al iniciar sesion
$settings = New-ScheduledTaskSettingsSet

Register-ScheduledTask -TaskName "DC01_Parte2" `
    -Action $action `
    -Trigger $trigger `
    -RunLevel Highest `   # permisos de Administrador, necesarios para configurar AD
    -Force | Out-Null

Write-Host "Tarea programada creada." -ForegroundColor Green

# Marcar como completado para evitar ejecucion multiple
"Completada" | Out-File "C:\AD_PARTE1_COMPLETADA.txt"

# --- Crear nuevo bosque de dominio ---
# Explicación: Promover a DC significa convertir este servidor en el nucleo
# del dominio ufv.local. Install-ADDSForest crea un bosque nuevo desde cero.
# Al terminar, Windows reinicia automaticamente y la tarea programada lanza la Parte 2.
Write-Host "[3/3] Promoviendo a Controlador de Dominio (ufv.local)..." -ForegroundColor Yellow

Import-Module ADDSDeployment

# Convertir la contrasena a SecureString (PowerShell no acepta texto plano aqui)
$DSRMPassword = ConvertTo-SecureString -String "Airbusds2026!" -AsPlainText -Force

Install-ADDSForest `
    -DomainName            "ufv.local" `
    -DomainNetbiosName     "UFV" `
    -ForestMode            "WinThreshold" `   # nivel funcional maximo (Windows Server 2016+)
    -DomainMode            "WinThreshold" `
    -SafeModeAdministratorPassword $DSRMPassword `   # contrasena de recuperacion del DC
    -InstallDns:$true `
    -Force
