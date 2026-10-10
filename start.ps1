$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw "Instale e inicie Docker Desktop com containers Linux." }
if (-not (Test-Path ".env")) {
  $bytes = New-Object byte[] 24
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
  $password = [Convert]::ToBase64String($bytes)
  @("DESKTOP_USER=nuke", "DESKTOP_PASSWORD=$password") | Set-Content -Encoding ascii ".env"
}
docker compose config --quiet
if ($LASTEXITCODE -ne 0) { throw "Configuracao invalida." }
docker compose up -d
if ($LASTEXITCODE -ne 0) { throw "Falha ao iniciar. Verifique Docker e conexao com o registro de imagens." }
Write-Host "Desktop iniciado; aguarde o carregamento inicial."
Write-Host "Endereco: https://localhost:3001"
Write-Host "Credenciais locais:"
Get-Content ".env" | Where-Object { $_ -match "^DESKTOP_(USER|PASSWORD)=" }
Write-Host "O certificado local e autoassinado. Confirme apenas ao acessar esse endereco local."
