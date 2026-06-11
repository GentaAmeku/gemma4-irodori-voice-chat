param(
  [string]$LanIp = "",
  [int]$Port = 8000,
  [string]$TaskName = "Gemma4 Irodori Chat Refresh PortProxy",
  [string]$ScriptPath = (Join-Path $PSScriptRoot "refresh-wsl-portproxy.ps1")
)

$ErrorActionPreference = "Stop"

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
  throw "Run this script from an elevated PowerShell."
}

$ResolvedScriptPath = [System.IO.Path]::GetFullPath($ScriptPath)
if (-not (Test-Path $ResolvedScriptPath)) {
  throw "refresh script was not found: $ResolvedScriptPath"
}

$argumentParts = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", "`"$ResolvedScriptPath`"",
  "-Port", "$Port",
  "-SkipHealthCheck"
)

if ($LanIp) {
  $argumentParts += @("-LanIp", $LanIp)
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ($argumentParts -join " ")
$principal = New-ScheduledTaskPrincipal `
  -UserId "$env:USERDOMAIN\$env:USERNAME" `
  -LogonType Interactive `
  -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet `
  -ExecutionTimeLimit (New-TimeSpan -Minutes 2)

Register-ScheduledTask `
  -TaskName $TaskName `
  -Action $action `
  -Principal $principal `
  -Settings $settings `
  -Description "Refresh Gemma4 Irodori Chat WSL portproxy and firewall rule for LAN clients." `
  -Force | Out-Null

Write-Host "Installed scheduled task:"
Write-Host "  $TaskName"
Write-Host ""
Write-Host "Run it manually with:"
Write-Host "  Start-ScheduledTask -TaskName `"$TaskName`""
Write-Host ""
Write-Host "WSL start script will try to run this task automatically."
