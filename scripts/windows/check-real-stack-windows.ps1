param(
  [string]$OllamaBaseUrl = "http://127.0.0.1:11434",
  [string]$TtsBaseUrl = "http://127.0.0.1:8088",
  [string]$AppBaseUrl = "http://127.0.0.1:8000"
)

$ErrorActionPreference = "Stop"

function Get-Json($Label, $Url) {
  Write-Host "Checking $Label..."
  Invoke-RestMethod -Uri $Url
  Write-Host ""
}

Get-Json "Ollama" "$OllamaBaseUrl/api/tags"
Get-Json "Irodori-TTS-Server health" "$TtsBaseUrl/health"
Get-Json "Irodori-TTS-Server voices" "$TtsBaseUrl/v1/audio/voices"
Get-Json "conversation server health" "$AppBaseUrl/api/health"

Write-Host "Checking text turn..."
Invoke-RestMethod `
  -Method Post `
  -Uri "$AppBaseUrl/api/turns/text" `
  -ContentType "application/json" `
  -Body '{"text":"実接続の確認です。短く返事してください。"}'
