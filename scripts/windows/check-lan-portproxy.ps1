param(
  [string]$LanIp = "",
  [int]$Port = 8000,
  [string]$FirewallRuleName = "Gemma4 Irodori Chat API 8000"
)

$ErrorActionPreference = "Stop"

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
    throw "Could not resolve the Windows LAN IPv4. Pass -LanIp, for example: -LanIp 192.168.3.2"
  }

  return $candidate.IPAddress
}

function Resolve-WslIp {
  $raw = (& wsl hostname -I 2>$null)
  if ($LASTEXITCODE -ne 0 -or -not $raw) {
    return ""
  }

  return ($raw -split "\s+" | Where-Object { $_ -match "^\d{1,3}(\.\d{1,3}){3}$" } | Select-Object -First 1)
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

$ResolvedLanIp = Resolve-LanIp $LanIp
$WslIp = Resolve-WslIp
$LocalUrl = "http://127.0.0.1:$Port/api/health"
$LanUrl = "http://$ResolvedLanIp`:$Port/api/health"

Write-Host "LAN portproxy diagnostic"
Write-Host "  Windows LAN IP: $ResolvedLanIp"
Write-Host "  WSL IP:         $(if ($WslIp) { $WslIp } else { "(not resolved)" })"
Write-Host "  Port:           $Port"
Write-Host ""

Write-Host "iphlpsvc:"
Get-Service iphlpsvc | Format-Table -AutoSize

Write-Host "Network profile:"
Get-NetConnectionProfile | Format-Table InterfaceAlias, InterfaceIndex, NetworkCategory, IPv4Connectivity -AutoSize

Write-Host "Firewall rule:"
$rule = Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue
if ($rule) {
  $rule | Format-Table DisplayName, Enabled, Direction, Action, Profile -AutoSize
  $rule | Get-NetFirewallAddressFilter | Format-Table LocalAddress, RemoteAddress -AutoSize
  $rule | Get-NetFirewallPortFilter | Format-Table Protocol, LocalPort, RemotePort -AutoSize
}
else {
  Write-Host "  (missing) $FirewallRuleName"
}

Write-Host "portproxy:"
netsh interface portproxy show v4tov4

Write-Host ""
Write-Host "Health:"
$LocalOk = Test-Http $LocalUrl
$LanOk = Test-Http $LanUrl
Write-Host "  $LocalUrl => $LocalOk"
Write-Host "  $LanUrl => $LanOk"

if (-not $LocalOk) {
  Write-Error "Conversation server is not reachable on localhost. Start the WSL conversation server first."
  exit 1
}

if (-not $LanOk) {
  Write-Error "Conversation server is reachable on localhost but not on the LAN IP. Refresh portproxy/firewall."
  exit 2
}

Write-Host ""
Write-Host "LAN portproxy OK."
