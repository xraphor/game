# NUKE FOOTBALL

Jogo de treinamento de futebol 3D local, criado em **Godot 4.6.3**. O pedido mais recente substitui Unreal Engine por uma engine gratuita. Esta versão tem jogadores com anatomia detalhada e esqueleto de 18 ossos, uniformes com tecido, bola de 32 painéis, gramado com milhares de lâminas e iluminação de fim de tarde com ambiente HDRI.

O projeto mira Windows PC e também pode ser aberto e executado em Linux. Funciona sem conta, servidor, API ou licença comercial de engine.

## Baixar o jogo pronto

[Baixar NUKE FOOTBALL para Windows](https://github.com/xraphor/game/raw/refs/heads/codex/nuke-football-download/downloads/NUKE-FOOTBALL-Windows.zip). Extraia o ZIP e abra `NUKE-FOOTBALL.exe`; não precisa instalar Godot ou Unreal para jogar o executável.

O [projeto completo em ZIP](https://github.com/xraphor/game/raw/refs/heads/codex/nuke-football-download/downloads/NUKE-FOOTBALL-Projeto-Godot.zip) e uma imagem real do jogo estão na [pasta de downloads](downloads/README.md).

## Abrir e jogar

1. Instale a versão padrão da [Godot 4.6.3](https://godotengine.org/download/archive/4.6.3-stable/); a edição .NET não é necessária.
2. Importe o arquivo `project.godot` no gerenciador de projetos.
3. Abra o projeto e pressione **F5**. Com `scenes/main.tscn` aberta, **F6** também executa a cena principal.
4. Escolha exercício, dificuldade, qualidade e presença do defensor no menu; clique em **ENTRAR EM CAMPO**.

Com `godot` disponível no terminal, execute na raiz do projeto:

```sh
godot --path .
```

É necessário um computador de 64 bits. O renderizador Forward+ usa Vulkan para iluminação, reflexos e oclusão ambiente na qualidade alta. Em máquinas incompatíveis, a Godot tenta o renderizador OpenGL 3.3 automaticamente. Para escolhê-lo manualmente, execute `NUKE-FOOTBALL.exe --rendering-method gl_compatibility` ou `godot --path . --rendering-method gl_compatibility`. Use qualidade baixa para reduzir sombras, público, lâminas de grama e suavização de bordas.

## Controles

O movimento acompanha a orientação da câmera. A condução acontece por toques físicos quando você se aproxima da bola; ela não fica presa ao jogador. Para chutar ou passar, fique perto da bola.

| Ação | Teclado e mouse | Controle, padrão Xbox |
| --- | --- | --- |
| Mover | WASD ou setas | Analógico esquerdo |
| Correr | Shift | RT ou RB |
| Mirar | Mover o mouse sobre o campo | Analógico direito |
| Chutar | Segurar e soltar Espaço ou botão esquerdo do mouse | Segurar e soltar A |
| Passar ao companheiro | E | X |
| Movimento preciso / chute rasteiro | — | LT |
| Alternar câmera | C | LB ou B |
| Zoom | Roda do mouse | D-pad ↑/↓ durante o jogo |
| Repor jogadores e bola | R | Y |
| Pausar e continuar | Esc | Menu/Start |
| Ver comandos na pausa | F1 | View |
| Navegar pelos menus | Setas, Enter/Espaço, Esc | D-pad/LS, A confirmar, B voltar |

Conecte o Xbox por USB, Bluetooth ou adaptador sem fio reconhecido pelo sistema. O jogo detecta o controle sem reiniciar, adapta as dicas dos botões e usa zona morta radial para evitar movimentos involuntários. A desconexão pausa o treino e preserva o tempo. Chutes e gols acionam vibração quando o controle e o driver oferecem suporte. Os comandos completos aparecem no painel de pausa; todo o menu pode ser usado sem mouse.

Segurar o chute por mais tempo aumenta sua força e elevação. A barra e os pontos de trajetória ajudam a mirar; a previsão é aproximada. O companheiro procura uma linha de apoio e devolve passes quando alcança a bola. A câmera alterna entre treino, terceira pessoa e transmissão.

**R repõe as posições dentro da sessão atual:** mantém tempo decorrido, placar e progresso dos alvos, passes e cones. Para começar uma sessão do zero, use a opção de reiniciar no menu de pausa ou no resultado.

## Exercícios

Cada sessão dura até **90 segundos** e termina antes quando a meta é atingida.

| Exercício | Meta |
| --- | --- |
| Finalização | Fazer cinco gols contra o goleiro; defensor opcional |
| Chutes livres | Acertar os três alvos do gol, sem goleiro ou defensor |
| Passes | Completar três tabelas com o companheiro |
| Cones | Levar jogador e bola pelos cinco portões, na ordem indicada |
| 1 contra 1 | Superar o defensor e fazer cinco gols contra o goleiro |

O gol conta quando a bola inteira cruza a linha entre as traves e abaixo do travessão. A bola é reposta automaticamente depois de um gol ou quando sai do campo. As dificuldades fácil, média e difícil ajustam o intervalo de observação, velocidade e alcance dos bots. Eles reagem à bola observada, com atraso, e se movem pelo campo.

## Desenvolvimento e verificação

O projeto usa GDScript e traz os modelos GLB e o HDRI prontos: não há dependências de pacotes para instalar. Os dois geradores originais em `tools/` permitem recriar jogador e bola com Blender 4.3+; Blender não é necessário para jogar ou abrir o projeto. Para importar e verificar o projeto sem abrir uma janela:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/run_tests.gd
```

Em ambientes na nuvem que não permitem gravar na pasta pessoal, direcione os diretórios de execução para um local gravável antes de chamar a Godot:

```sh
export XDG_DATA_HOME=/tmp/nuke-football/data
export XDG_CACHE_HOME=/tmp/nuke-football/cache
export XDG_CONFIG_HOME=/tmp/nuke-football/config
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
```

O projeto passou pela importação/análise dos scripts, **93 verificações de integração (93 passaram, nenhuma falhou)** e execução gráfica em Linux, inclusive do executável exportado. A suíte exercita física real, movimento, chutes, gols, bots, tabelas, cones, pausa, reinício, qualidade, postura do esqueleto e 22 verificações de Xbox com eventos simulados enviados pelo pipeline de entrada da Godot. A exportação Windows foi gerada; **a execução em Windows ainda precisa ser verificada em um PC Windows**. Não foi possível testar um controle Xbox físico neste ambiente. Vibração, drivers e desempenho da GPU precisam de teste local.

## Gerar executáveis

Instale os **templates de exportação oficiais da Godot 4.6.3** pelo menu **Editor → Gerenciar templates de exportação**. O projeto já contém os presets `Windows Desktop` e `Linux Desktop`. Pela interface, use **Projeto → Exportar**; pelo terminal, na raiz do repositório:

```sh
mkdir -p build/windows build/linux
godot --headless --path . --export-release "Windows Desktop" build/windows/NUKE-FOOTBALL.exe
godot --headless --path . --export-release "Linux Desktop" build/linux/NUKE-FOOTBALL.x86_64
```

As saídas ficam em `build/`, que não é versionado. O pacote do jogo está embutido no executável pelos presets. No Linux, execute `./build/linux/NUKE-FOOTBALL.x86_64`; no Windows, abra `NUKE-FOOTBALL.exe`.

## Escopo desta versão

O campo de treino mede 36 × 56 metros. Há bola física, goleiro, defensor, companheiro, animações procedurais, placar, cronômetro, pausa, três câmeras, três níveis de qualidade e sons sintetizados. A anatomia utiliza uma malha CC0 do MakeHuman, com uniforme e animações adaptados para o projeto. A iluminação usa HDRI CC0 do Poly Haven; a arena, bola, interface e áudio são originais. O visual foi melhorado, mas esta versão de treino ainda não tem o acabamento de uma produção AAA.

Não há multiplayer, partidas completas, regras de faltas/impedimento, replays, chuva ou campanha persistente. As próximas ambições e critérios do projeto permanecem em [GAME_DESIGN.md](GAME_DESIGN.md). A origem dos recursos e as licenças da engine estão documentadas em [assets/LICENSES.md](assets/LICENSES.md).

Para gerar os ZIPs depois de exportar ambos os executáveis, use `python3 tools/package_game.py`. Os pacotes e checksums ficam em `build/packages/`.
