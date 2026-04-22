# ============================================================
# DC01 - PARTE 2: Configurar DNS, DHCP, NTP, CIFS, OUs,
#                 Usuarios, Grupos y GPOs
# ============================================================
# Explicación: Se ejecuta automaticamente tras el reinicio de la Parte 1
# gracias a la tarea programada creada por ese script.
# Tambien puedes lanzarlo manualmente abriendo PowerShell como Administrador.
# ============================================================

# Guardar todo lo que aparece en pantalla en un fichero de log
Start-Transcript -Path "C:\DC01_Parte2_Log.txt" -Append
Write-Host "=== PARTE 2: Configurando servicios del DC ===" -ForegroundColor Cyan

# Explicación: AD tarda un momento en arrancar completamente despues del reinicio.
# Si empezamos demasiado rapido, los comandos de AD fallan porque el servicio
# todavia no esta listo para responder.
Write-Host "Esperando a que Active Directory este listo..." -ForegroundColor Yellow
Start-Sleep -Seconds 60
Import-Module ActiveDirectory

# ----------------------------------------------------------
# 1. Configurar DNS
# ----------------------------------------------------------
Write-Host "[1/7] Configurando DNS..." -ForegroundColor Yellow

# Explicación: El DNS de AD resuelve nombres dentro del dominio (ufv.local).
# Para resolver nombres de Internet necesita reenviar la consulta a un DNS externo.
# Usamos Cloudflare (1.1.1.1) y Google (8.8.8.8).
Set-DnsServerForwarder -IPAddress "1.1.1.1", "8.8.8.8"

# Crear zonas DNS
# Explicación: La zona inversa permite dado una IP obtener su nombre (DNS inverso).
# Ejemplo: 10.0.1.10 → DC01.ufv.local
Add-DnsServerPrimaryZone -NetworkID "10.0.1.0/24" -ReplicationScope "Domain" -ErrorAction SilentlyContinue

Write-Host "DNS configurado." -ForegroundColor Green

# ----------------------------------------------------------
# 2. Instalar DHCP
# ----------------------------------------------------------
Write-Host "[2/7] Instalando y configurando DHCP..." -ForegroundColor Yellow

Install-WindowsFeature -Name DHCP -IncludeManagementTools

# Explicación: AD requiere que los servidores DHCP esten "autorizados" para evitar
# que cualquier maquina de la red empiece a dar IPs sin permiso.
Add-DhcpServerInDC -DnsName "DC01.ufv.local" -IPAddress "10.0.1.10"

# Crear ambito
Add-DhcpServerV4Scope -Name "UFV-Red" `
    -StartRange "10.0.1.100" `
    -EndRange   "10.0.1.150" `
    -SubnetMask "255.255.255.0" `
    -State Active

# Explicación: Excluimos las IPs que ya tienen asignacion fija (el DC y el cliente Windows)
# para que el DHCP no se las asigne a otro equipo.
Add-DhcpServerV4ExclusionRange -ScopeId "10.0.1.0" -StartRange "10.0.1.10" -EndRange "10.0.1.11"

# Configurar opciones
Set-DhcpServerV4OptionValue -ScopeId "10.0.1.0" `
    -Router    "10.0.1.1" `
    -DnsServer "10.0.1.10" `
    -DnsDomain "ufv.local"

Write-Host "DHCP configurado." -ForegroundColor Green

# ----------------------------------------------------------
# 3. Configurar NTP (Network Time Protocol)
# ----------------------------------------------------------
# Explicación: En un dominio AD es critico que todos los equipos tengan la hora
# sincronizada. Si hay mas de 5 minutos de diferencia, Kerberos rechaza los
# inicios de sesion. El DC es el servidor de tiempo de referencia del dominio.
Write-Host "[3/7] Configurando NTP..." -ForegroundColor Yellow

# Configurar como cliente NTP
w32tm /config /manualpeerlist:"0.pool.ntp.org,1.pool.ntp.org" /syncfromflags:manual /reliable:yes /update

# Configurar como servidor NTP para el dominio
net stop w32time  | Out-Null
net start w32time | Out-Null
w32tm /resync /rediscover | Out-Null

# Crear regla de firewall para que los clientes Linux puedan sincronizar su hora
New-NetFirewallRule -DisplayName "NTP-Allow-Inbound" `
    -Direction Inbound `
    -Protocol UDP `
    -LocalPort 123 `
    -Action Allow `
    -ErrorAction SilentlyContinue

# Verificar
# w32tm /query /status

Write-Host "NTP configurado." -ForegroundColor Green

# ----------------------------------------------------------
# 4. Recurso CIFS (carpeta compartida en red)
# ----------------------------------------------------------
# Explicación: CIFS es el protocolo de Windows para compartir carpetas.
# La GPO de la seccion 7 mapeara esta carpeta automaticamente como unidad Z:.
Write-Host "[4/7] Creando recurso CIFS..." -ForegroundColor Yellow

$cifsPath = "C:\UFV_Share"
if (-not (Test-Path $cifsPath)) { New-Item -ItemType Directory -Path $cifsPath | Out-Null }

New-SmbShare -Name "UFV_Share" `
    -Path $cifsPath `
    -FullAccess "UFV\Domain Users" `
    -ErrorAction SilentlyContinue

Write-Host "Recurso CIFS creado: \\DC01\UFV_Share" -ForegroundColor Green

# ----------------------------------------------------------
# 5. OUs, Grupo y Usuarios de Active Directory
# ----------------------------------------------------------
Write-Host "[5/7] Creando OUs, grupo y usuarios..." -ForegroundColor Yellow

# Crear OUs
New-ADOrganizationalUnit -Name "UFV_Users"     -Path "DC=ufv,DC=local" -ErrorAction SilentlyContinue
New-ADOrganizationalUnit -Name "UFV_Computers" -Path "DC=ufv,DC=local" -ErrorAction SilentlyContinue

# Crear grupos
New-ADGroup -Name "UFV_group" `
    -GroupScope Global `
    -GroupCategory Security `
    -Path "OU=UFV_Users,DC=ufv,DC=local" `
    -ErrorAction SilentlyContinue

# Crear usuarios
$password = ConvertTo-SecureString "Airbusds2026!" -AsPlainText -Force

New-ADUser -Name "user1" `
    -SamAccountName "user1" `
    -UserPrincipalName "user1@ufv.local" `
    -Path "OU=UFV_Users,DC=ufv,DC=local" `
    -AccountPassword $password `
    -Enabled $true `
    -ErrorAction SilentlyContinue

New-ADUser -Name "user2" `
    -SamAccountName "user2" `
    -UserPrincipalName "user2@ufv.local" `
    -Path "OU=UFV_Users,DC=ufv,DC=local" `
    -AccountPassword $password `
    -Enabled $true `
    -ErrorAction SilentlyContinue

# Añadir miembros
Add-ADGroupMember -Identity "UFV_group" -Members "user1","user2"

Write-Host "OUs, grupo y usuarios creados." -ForegroundColor Green

# ----------------------------------------------------------
# 6. GPO 1: Impedir apagar la maquina
# ----------------------------------------------------------
# Explicación: Una GPO es un conjunto de configuraciones que Windows aplica
# automaticamente a usuarios o equipos del dominio. Esta impide que los
# usuarios de UFV_group vean el boton de apagado.
Write-Host "[6/7] Creando GPO_NoShutdown..." -ForegroundColor Yellow

Import-Module GroupPolicy

New-GPO -Name "GPO_NoShutdown" -ErrorAction SilentlyContinue

# NoClose = 1 oculta el boton de apagar/cerrar sesion para el usuario
Set-GPRegistryValue -Name "GPO_NoShutdown" `
    -Key       "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
    -ValueName "NoClose" `
    -Type      DWord `
    -Value     1

# Vincular GPO a la OU UFV_Users
New-GPLink -Name "GPO_NoShutdown" `
    -Target "OU=UFV_Users,DC=ufv,DC=local" `
    -ErrorAction SilentlyContinue

# Explicación: Por defecto la GPO se aplica a todos los usuarios (Authenticated Users).
# Quitamos ese permiso y lo damos solo a UFV_group para filtrar la aplicacion.
Set-GPPermission -Name "GPO_NoShutdown" `
    -TargetName "Authenticated Users" `
    -TargetType Group `
    -PermissionLevel None `
    -ErrorAction SilentlyContinue

Set-GPPermission -Name "GPO_NoShutdown" `
    -TargetName "UFV_group" `
    -TargetType Group `
    -PermissionLevel GpoApply

Write-Host "GPO_NoShutdown creada y vinculada." -ForegroundColor Green

# ----------------------------------------------------------
# 7. GPO 2: Mapear unidad de red Z: automaticamente
# ----------------------------------------------------------
# Explicación: Cuando un usuario de UFV_group inicia sesion, Windows le monta
# automaticamente la carpeta compartida UFV_Share como unidad de red Z:.
# Se configura mediante claves de registro en HKCU\Network\Z.
Write-Host "[7/7] Creando GPO_NetworkDrive..." -ForegroundColor Yellow

New-GPO -Name "GPO_NetworkDrive" -ErrorAction SilentlyContinue

# Ruta UNC de la carpeta compartida a mapear como Z:
Set-GPRegistryValue -Name "GPO_NetworkDrive" `
    -Key       "HKCU\Network\Z" `
    -ValueName "RemotePath" `
    -Type      String `
    -Value     "\\DC01\UFV_Share"

# Credenciales de conexion (vacio = usar las del usuario actual)
Set-GPRegistryValue -Name "GPO_NetworkDrive" `
    -Key       "HKCU\Network\Z" `
    -ValueName "UserName" `
    -Type      String `
    -Value     ""

# Proveedor de red SMB/CIFS de Windows
Set-GPRegistryValue -Name "GPO_NetworkDrive" `
    -Key       "HKCU\Network\Z" `
    -ValueName "ProviderName" `
    -Type      String `
    -Value     "Microsoft Windows Network"

# Flags de conexion (0 = comportamiento por defecto)
Set-GPRegistryValue -Name "GPO_NetworkDrive" `
    -Key       "HKCU\Network\Z" `
    -ValueName "ConnectFlags" `
    -Type      DWord `
    -Value     0

# Vincular GPO a la OU UFV_Users
New-GPLink -Name "GPO_NetworkDrive" `
    -Target "OU=UFV_Users,DC=ufv,DC=local" `
    -ErrorAction SilentlyContinue

# Filtrar: solo aplica a UFV_group
Set-GPPermission -Name "GPO_NetworkDrive" `
    -TargetName "Authenticated Users" `
    -TargetType Group `
    -PermissionLevel None `
    -ErrorAction SilentlyContinue

Set-GPPermission -Name "GPO_NetworkDrive" `
    -TargetName "UFV_group" `
    -TargetType Group `
    -PermissionLevel GpoApply

Write-Host "GPO_NetworkDrive creada y vinculada." -ForegroundColor Green

# Aplicar todas las GPOs ahora sin esperar al proximo inicio de sesion
gpupdate /force | Out-Null

# ----------------------------------------------------------
# Verificacion final
# ----------------------------------------------------------
Write-Host "`n=== VERIFICACION FINAL ===" -ForegroundColor Cyan

Write-Host "`n-- Servicio AD:" -ForegroundColor White
Get-Service NTDS | Select-Object Name, Status

Write-Host "`n-- Servicio DNS:" -ForegroundColor White
Get-Service DNS | Select-Object Name, Status

Write-Host "`n-- Servicio DHCP:" -ForegroundColor White
Get-Service DHCPServer | Select-Object Name, Status

Write-Host "`n-- Dominio:" -ForegroundColor White
Get-ADDomain | Select-Object DNSRoot, NetBIOSName

Write-Host "`n-- OUs:" -ForegroundColor White
Get-ADOrganizationalUnit -Filter * | Select-Object Name

Write-Host "`n-- Usuarios en UFV_group:" -ForegroundColor White
Get-ADGroupMember -Identity "UFV_group" | Select-Object Name

Write-Host "`n-- GPOs:" -ForegroundColor White
Get-GPO -All | Select-Object DisplayName, GpoStatus

# Verificar NTP
Write-Host "`n-- NTP:" -ForegroundColor White
w32tm /query /status

Write-Host "`n-- CIFS:" -ForegroundColor White
Get-SmbShare -Name "UFV_Share" | Select-Object Name, Path

Write-Host "`n=== CONFIGURACION COMPLETADA ===" -ForegroundColor Green
Write-Host "Revisa C:\DC01_Parte2_Log.txt para el log completo." -ForegroundColor Yellow

# Eliminar tarea programada (ya no es necesaria)
Unregister-ScheduledTask -TaskName "DC01_Parte2" -Confirm:$false -ErrorAction SilentlyContinue

Stop-Transcript
