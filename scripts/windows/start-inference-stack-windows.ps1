param(
  [string]$IrodoriDir = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "..\Irodori-TTS-Server"),
  [string]$OllamaHost = "127.0.0.1:11434",
  [string]$IrodoriHost = "0.0.0.0",
  [int]$IrodoriPort = 8088,
  [ValidateSet("cpu")]
  [string]$IrodoriExtra = "cpu"
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$LogDir = if ($env:GIC_LOG_DIR) { $env:GIC_LOG_DIR } else { Join-Path $RootDir ".logs" }
$ResolvedIrodoriDir = [System.IO.Path]::GetFullPath($IrodoriDir)

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Require-Command($Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "missing command: $Name"
  }
}

function Test-Http($Url) {
  try {
    Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2 | Out-Null
    return $true
  }
  catch {
    return $false
  }
}

function Wait-Http($Url, $Name, $Attempts = 60) {
  for ($i = 0; $i -lt $Attempts; $i++) {
    if (Test-Http $Url) {
      Write-Host "$Name ready: $Url"
      return
    }
    Start-Sleep -Seconds 1
  }
  throw "$Name did not become ready: $Url"
}

Require-Command ollama
Require-Command uv

if (-not (Test-Http "http://$OllamaHost/api/tags")) {
  Write-Host "Starting Ollama..."
  $env:OLLAMA_HOST = $OllamaHost
  $ollamaOutLog = Join-Path $LogDir "ollama.out.log"
  $ollamaErrLog = Join-Path $LogDir "ollama.err.log"
  $ollamaProcess = Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden -PassThru -RedirectStandardOutput $ollamaOutLog -RedirectStandardError $ollamaErrLog
  $ollamaProcess.Id | Set-Content (Join-Path $LogDir "ollama.pid")
  Wait-Http "http://$OllamaHost/api/tags" "Ollama"
}
else {
  Write-Host "Ollama already running: http://$OllamaHost"
}

if (-not (Test-Path $ResolvedIrodoriDir)) {
  throw "Irodori-TTS-Server directory was not found: $ResolvedIrodoriDir. Run scripts\windows\setup-irodori-windows.ps1 first."
}

if (-not (Test-Http "http://127.0.0.1:$IrodoriPort/health")) {
  Write-Host "Starting Irodori-TTS-Server in Windows CPU mode..."
  $irodoriOutLog = Join-Path $LogDir "irodori.out.log"
  $irodoriErrLog = Join-Path $LogDir "irodori.err.log"
  $irodoriArgs = @("run", "--extra", $IrodoriExtra, "python", "-m", "irodori_openai_tts", "--host", $IrodoriHost, "--port", "$IrodoriPort")
  $irodoriProcess = Start-Process -FilePath "uv" -ArgumentList $irodoriArgs -WorkingDirectory $ResolvedIrodoriDir -WindowStyle Hidden -PassThru -RedirectStandardOutput $irodoriOutLog -RedirectStandardError $irodoriErrLog
  $irodoriProcess.Id | Set-Content (Join-Path $LogDir "irodori.pid")
  Wait-Http "http://127.0.0.1:$IrodoriPort/health" "Irodori-TTS-Server" 120
}
else {
  Write-Host "Irodori-TTS-Server already running: http://127.0.0.1:$IrodoriPort"
}

Write-Host ""
Write-Host "Inference stack is ready."
Write-Host ""
Write-Host "Logs:"
Write-Host "  $(Join-Path $LogDir "ollama.out.log")"
Write-Host "  $(Join-Path $LogDir "ollama.err.log")"
Write-Host "  $(Join-Path $LogDir "irodori.out.log")"
Write-Host "  $(Join-Path $LogDir "irodori.err.log")"
Write-Host ""
Write-Host "Next, start this app's conversation server:"
Write-Host "  .\scripts\windows\start-conversation-server-real-windows.ps1"
