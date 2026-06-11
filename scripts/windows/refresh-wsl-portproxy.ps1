param(
  [string]$LanIp = "",
  [int]$Port = 8000,
  [string]$FirewallRuleName = "Gemma4 Irodori Chat API 8000",
  [switch]$SkipHealthCheck
)

$ErrorActionPreference = "Stop"

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-LanIp {
  param([string]$PreferredLanIp)

  if ($PreferredLanIp) {
    return $PreferredLanIp
  }

  $candidate = Get-NetIPConfiguration |
    Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq "Up" } |
    ForEach-Object { $_.IPv4Address } |
    Where-Object { $_.IPAddress -and $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } |
    Select-Object -First 1

  if (-not $candidate) {
    throw "Could not resolve the Windows LAN IPv4. Pass -LanIp, for example: -LanIp 192.168.0.10"
  }

  return $candidate.IPAddress
}

function Resolve-WslIp {
  $raw = (& wsl hostname -I 2>$null)
  if ($LASTEXITCODE -ne 0 -or -not $raw) {
    throw "Could not run 'wsl hostname -I'. Start WSL first."
  }

  $ip = ($raw -split "\s+" | Where-Object { $_ -match "^\d{1,3}(\.\d{1,3}){3}$" } | Select-Object -First 1)
  if (-not $ip) {
    throw "Could not resolve the WSL IPv4 from: $raw"
  }

  return $ip
}

function Test-Http {
  param([string]$Url)

  try {
    Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 | Out-Null
    return $true
  }
  catch {
    return $false
  }
}

if (-not (Test-Administrator)) {
  throw "Run this script from an elevated PowerShell, or install the scheduled task with scripts\windows\install-portproxy-refresh-task.ps1."
}

$ResolvedLanIp = Resolve-LanIp $LanIp
$WslIp = Resolve-WslIp

Write-Host "Refreshing WSL portproxy..."
Write-Host "  Windows LAN IP: $ResolvedLanIp"
Write-Host "  WSL IP:         $WslIp"
Write-Host "  Port:           $Port"

$service = Get-Service iphlpsvc
if ($service.Status -ne "Running") {
  Start-Service iphlpsvc
}

netsh interface portproxy delete v4tov4 listenaddress=$ResolvedLanIp listenport=$Port | Out-Null
netsh interface portproxy add v4tov4 listenaddress=$ResolvedLanIp listenport=$Port connectaddress=$WslIp connectport=$Port | Out-Null

Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule `
  -DisplayName $FirewallRuleName `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalAddress $ResolvedLanIp `
  -LocalPort $Port `
  -Profile Private | Out-Null

Restart-Service iphlpsvc -Force

Write-Host ""
Write-Host "Current portproxy:"
netsh interface portproxy show v4tov4

if (-not $SkipHealthCheck) {
  $LocalUrl = "http://127.0.0.1:$Port/api/health"
  $LanUrl = "http://$ResolvedLanIp`:$Port/api/health"

  Write-Host ""
  Write-Host "Checking conversation server health..."
  if (-not (Test-Http $LocalUrl)) {
    throw "Conversation server is not reachable on $LocalUrl. Start scripts\wsl\start-conversation-server-wsl.sh or scripts\wsl\start-desktop-stack.sh first."
  }
  if (-not (Test-Http $LanUrl)) {
    throw "Conversation server is reachable on localhost but not on $LanUrl. Check NetworkCategory and firewall profile."
  }
  Write-Host "LAN health OK: $LanUrl"
}

Write-Host ""
Write-Host "Portproxy refresh complete."
