param(
  [string]$IrodoriDir = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "..\Irodori-TTS-Server")
)

$ErrorActionPreference = "Stop"

function Require-Command($Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "missing command: $Name"
  }
}

Require-Command git
Require-Command uv

$ResolvedIrodoriDir = [System.IO.Path]::GetFullPath($IrodoriDir)

if (-not (Test-Path (Join-Path $ResolvedIrodoriDir ".git"))) {
  git clone https://github.com/Aratako/Irodori-TTS-Server.git $ResolvedIrodoriDir
}

Push-Location $ResolvedIrodoriDir
try {
  uv sync --extra cpu
  if ((-not (Test-Path ".env")) -and (Test-Path ".env.example")) {
    Copy-Item ".env.example" ".env"
  }
}
finally {
  Pop-Location
}

Write-Host "Irodori-TTS-Server is set up for Windows CPU mode:"
Write-Host "  $ResolvedIrodoriDir"
Write-Host ""
Write-Host "Start it with:"
Write-Host "  cd `"$ResolvedIrodoriDir`""
Write-Host "  uv run --extra cpu python -m irodori_openai_tts --host 0.0.0.0 --port 8088"
