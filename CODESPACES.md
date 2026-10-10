# Usar sem cartao: GitHub Codespaces
Esta opcao e para desenvolver e testar o desktop. Nao e um servidor permanente nem um PC gamer. A execucao grafica desta configuracao ainda precisa ser validada em uma sessao real.

1. Abra https://github.com/codespaces/new?repo=xraphor/game e entre na conta xraphor.
2. Selecione main, a configuracao NUKE PC e a menor maquina disponivel (2 cores).
3. Crie o codespace. O comando de inicio roda automaticamente e baixa a imagem de desktop.
4. No terminal, execute cat .env para ver usuario e senha. Nao publique esse arquivo.
5. Na aba Ports/Portas, mantenha 3001 como PRIVATE e protocolo HTTPS; abra o link no navegador.
6. Se a inicializacao falhar, execute bash start.sh no terminal e examine docker compose logs --tail=100 desktop.

A conta pessoal GitHub Free inclui 120 core-hours por ciclo mensal: uma maquina de 2 cores equivale a aproximadamente 60 horas ativas se nao houver outros usos. Armazenamento tambem tem cota, 15 GB-month, e imagens/arquivos adicionais consomem esse limite. Sem forma de pagamento cadastrada, o uso e bloqueado ao esgotar a cota. Confira o saldo na sua conta antes de criar.

Pare a sessao pelo menu do Codespaces quando terminar. Fechar o navegador nao garante parada imediata. Ha timeout de inatividade; nao use mecanismos para burlar esse limite. Parar nao elimina consumo de armazenamento. Excluir o codespace pode apagar os dados; exporte arquivos importantes primeiro.

Nao ha sessao criada automaticamente por este commit. Criar a sessao requer sua conta GitHub. O desktop e Linux; compatibilidade com programas Windows e jogos nao e garantida.

Fontes:
https://docs.github.com/en/codespaces/about-codespaces/what-are-codespaces
https://docs.github.com/en/billing/concepts/product-billing/github-codespaces
