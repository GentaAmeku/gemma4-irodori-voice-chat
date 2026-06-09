param(
  [string]$OllamaHost = "127.0.0.1:11434",
  [string]$OllamaModel = "gemma4:e4b-mlx",
  [string]$TtsBaseUrl = "http://127.0.0.1:8088"
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ServerDir = Join-Path $RootDir "server"

Push-Location $ServerDir
try {
  $env:GIC_OLLAMA_BASE_URL = "http://$OllamaHost"
  $env:GIC_OLLAMA_MODEL = $OllamaModel
  $env:GIC_TTS_BASE_URL = $TtsBaseUrl
  uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
}
finally {
  Pop-Location
}
