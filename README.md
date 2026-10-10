# NUKE PC
Desktop Linux real acessado pelo navegador, executado em um container Ubuntu XFCE com LinuxServer Webtop. Este projeto substitui o jogo de futebol.

## Estado
Configuracao e scripts de inicializacao preparados. Nenhum servidor foi provisionado e a sessao grafica ainda nao foi testada neste ambiente, que nao possui Docker. Nao existe link publico ativo.

## Windows
Instale Docker Desktop com WSL2 e containers Linux; mantenha Docker em execucao.
Baixe ou clone este repositorio e abra PowerShell na pasta:
```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```
O script gera uma senha local e inicia o desktop. Abra **https://localhost:3001** e use as credenciais mostradas. Aguarde o primeiro download e carregamento. O certificado HTTPS local e autoassinado.

## Linux
Com Docker Engine, Compose e openssl instalados:
```bash
bash start.sh
```
Abra https://localhost:3001. Usuario e senha ficam no arquivo local .env, ignorado pelo Git.

## O que voce pode usar
Area de trabalho, terminal e aplicativos Linux da imagem. Os recursos de transferencia, audio e entrada dependem do navegador e da configuracao do Webtop. Arquivos da pasta pessoal ficam no volume desktop-data e sobrevivem a recriacao do container. Aplicativos instalados fora dessa pasta podem desaparecer ao recriar a imagem; use imagem personalizada para instala-los permanentemente.

## Gerenciar
```bash
docker compose ps
docker compose logs --tail=100 desktop
docker compose stop
docker compose start
docker compose down
```
Fechar a aba nao para o container. Os processos continuam apenas enquanto a maquina hospedeira e o container estiverem ligados. Evite executar down -v: isso apaga os dados persistentes.
Para atualizar: docker compose pull e depois docker compose up -d.

## Acesso remoto
Por padrao, o servico so aceita conexoes locais. Para usar o desktop de um servidor pessoal sem abrir a porta na internet:
```bash
ssh -L 3001:127.0.0.1:3001 usuario@seu-servidor
```
Mantenha o tunel aberto e acesse https://localhost:3001 no seu computador. Execute o projeto primeiro no servidor. Para acesso publico ou pelo celular, ainda e necessario configurar hospedagem, HTTPS e autenticacao adequados.

## Limites
Este e um desktop Linux em container, compartilhando o kernel do host, nao uma VM Windows. Nao executa todos os programas Windows nem garante suporte a Roblox ou jogos com anticheat. Desempenho depende de CPU, RAM, GPU e rede do host. GitHub armazena o codigo; nao fornece um PC permanente com este repositorio. Nao montamos o socket Docker, diretorios do host ou modo privilegiado.

## Documentacao da dependencia
https://docs.linuxserver.io/images/docker-webtop/
