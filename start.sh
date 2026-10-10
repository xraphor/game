#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
command -v docker >/dev/null || { echo "Instale Docker com Compose."; exit 1; }
if [ ! -f .env ]; then
  command -v openssl >/dev/null || { echo "Instale openssl para gerar a senha."; exit 1; }
  (umask 077; printf 'DESKTOP_USER=nuke\nDESKTOP_PASSWORD=%s\nPUID=%s\nPGID=%s\n' "$(openssl rand -hex 24)" "$(id -u)" "$(id -g)" > .env)
fi
docker compose config --quiet
docker compose up -d
printf 'Aguarde o primeiro carregamento. Abra https://localhost:3001\nCredenciais locais:\n'
sed -n '/^DESKTOP_USER=/p; /^DESKTOP_PASSWORD=/p' .env
printf 'O certificado local e autoassinado. Confirme apenas nesse endereco local.\n'
