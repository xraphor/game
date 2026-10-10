# NUKE FOOTBALL — proposta do jogo

## Pedido do usuário
Criar um jogo de futebol 3D muito realista, com visual brilhante e bots de treinamento.

## Base definida para o projeto
- Plataforma inicial: Windows PC.
- Engine proposta: Unreal Engine 5, com C++ e Blueprints.
- Jogo local, sem necessidade de servidor ou API de inteligência artificial.
- Nome provisório: NUKE FOOTBALL.
- Prioridade: uma versão realmente jogável antes de ampliar o projeto.
- Essas escolhas podem ser alteradas por um novo pedido do usuário.

## Primeira versão jogável
Um campo de treinamento 3D com jogador controlável, bola física, gol, goleiro bot e um defensor bot. Implementar movimentação, corrida, condução, passe, chute com força variável, contagem de gols e reinício do exercício. Entregar instruções para abrir o projeto e jogar.

## Aparência desejada
- Gramado detalhado, linhas do campo, estádio, traves e rede.
- Luz solar e refletores, sombras coerentes e reflexos fisicamente plausíveis.
- Materiais PBR: brilho de suor na pele, tecido dos uniformes, bola e superfícies molhadas.
- Evitar brilho excessivo que esconda a bola ou dificulte enxergar jogadores.
- Animações de corrida, domínio, passe, chute e defesa; transições suaves.
- Câmeras de transmissão, terceira pessoa e treino, com ajuste de distância.
- Opções de qualidade baixa, média e alta.
- Usar personagens e equipes originais. Documentar licenças de recursos externos.
- Recursos provisórios são aceitáveis durante o desenvolvimento, mas devem ser identificados; não descrever placeholders como gráficos finais realistas.

## Física e controles
- Bola com colisão, quique, atrito, rotação e desaceleração.
- Chutes calculados por direção e força; curva e elevação como expansão posterior.
- Condução com toques na bola, evitando prender a bola rigidamente ao jogador.
- Separar movimento físico da bola de lógica de posse.
- Suporte a teclado/mouse e controle, com mapeamento documentado.
- Feedback de força do chute e indicador discreto do jogador ativo.
- Pausa e reinício disponíveis durante os treinos.

## Bots de treinamento
- Goleiro: posicionamento em relação à bola e ao gol, reação com atraso configurável, tentativas de defesa e recuperação.
- Defensor: aproximação, marcação, interceptação e disputa de bola.
- Companheiro: oferecer linha de passe e devolver a bola.
- Usar máquina de estados ou behavior tree e navegação adequada ao campo.
- Dificuldade fácil, média e difícil ajustando reação, precisão e pressão.
- Bots não devem teleportar, atravessar adversários ou conhecer antecipadamente a entrada do jogador.
- Disponibilizar configuração para treinar sem defensor.

## Exercícios
1. Chutes livres com alvos e contagem de acertos.
2. Finalizações contra goleiro.
3. Drible entre cones com cronômetro.
4. Passes com companheiro bot.
5. Um contra um contra defensor.
6. Pênaltis como expansão após a base.
Mostrar pontuação, tentativas e opção de repetir.

## Expansão depois da base funcional
- Partidas curtas 3 contra 3, depois equipes maiores.
- Troca de jogador, bots de equipe, placar, tempo e reinício após gol.
- Faltas, laterais, escanteios e impedimento em etapas separadas.
- Sons de bola, chute, apito, rede e torcida com volume ajustável.
- Replays, chuva e horário do estádio depois das mecânicas principais.
- Não prometer multiplayer ou qualidade de produção AAA sem implementação e validação.

## Instrução para o Codex
Leia AGENTS.md e este documento. Inspecione o repositório e implemente a primeira versão jogável de NUKE FOOTBALL para Windows em Unreal Engine 5. Crie o projeto, as classes e os arquivos de configuração necessários; documente qualquer preparação manual do editor. Priorize jogador, bola física, gol, goleiro e defensor bots, chute, pontuação e reinício. Depois amplie os exercícios e o visual. Não entregue apenas um plano ou uma página HTML. Não apresente itens planejados como concluídos. Se Unreal Engine não estiver instalada no ambiente, entregue código e projeto com instruções exatas, e informe claramente que compilação e execução na engine ainda não foram verificadas.

## Critérios de validação
- Projeto abre na versão de Unreal Engine documentada.
- Jogador anda e corre sem atravessar o chão.
- Bola responde a condução e chute e colide com campo e traves.
- Gol só é contado quando a bola cruza a linha dentro da abertura.
- Goleiro e defensor executam comportamentos observáveis.
- Reinício restaura jogadores, bola e estado do exercício.
- README explica requisitos, controles, execução e limitações.
- Compilação e teste jogável registrados apenas quando realmente executados.
