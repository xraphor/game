# Origem dos recursos

O estádio, a interface, os uniformes e o áudio foram criados para este projeto. A anatomia humana e o ambiente HDRI utilizam recursos CC0:

- `icon.svg`: ícone vetorial original.
- `scripts/stadium.gd` e `shaders/grass.gdshader`: estádio, campo, materiais e gramado procedurais.
- `assets/models/athlete.glb`: anatomia derivada da malha base **MakeHuman**, CC0 1.0. O uniforme, o esqueleto de esporte, as chuteiras, materiais e animações são adaptações originais. Gerador em `tools/build_athlete.py`; fonte em `tools/source/human-base.obj.gz`. [Fonte](https://github.com/makehumancommunity/makehuman/blob/master/makehuman/data/3dobjs/base.obj), [licença de recursos](https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.ASSETS.md) e [texto CC0 incluído](MAKEHUMAN-CC0.md). Nenhum código do programa MakeHuman foi incorporado.
- `assets/models/football.glb`: bola original com 12 pentágonos, 20 hexágonos e costuras; gerador em `tools/build_ball.py`.
- `scripts/hud.gd`: interface e elementos gráficos desenhados pelo projeto.
- `scripts/sound.gd`: sons sintetizados por código; não utiliza gravações ou amostras externas.

- `assets/environment/blouberg_sunrise_2_1k.hdr`: **Blouberg Sunrise 2**, Greg Zaal, HDRI Haven/Poly Haven, CC0. Utilizado para iluminação e reflexos; o shader do céu adapta o horizonte ao estádio. [Origem](https://polyhaven.com/a/blouberg_sunrise_2), [espelho do arquivo](https://github.com/mrdoob/three.js/blob/dev/examples/textures/equirectangular/blouberg_sunrise_2_1k.hdr), [aviso incluído](POLYHAVEN-CC0.txt).

Não foram incorporadas marcas de clubes, músicas ou gravações de terceiros.

## Engine e fontes

O jogo utiliza **Godot Engine 4.6.3**, distribuída sob licença MIT. A Godot é gratuita e não exige royalties de engine. O texto MIT e os avisos das bibliotecas e fontes da engine instalada estão incluídos em [GODOT-LICENSE.txt](GODOT-LICENSE.txt), extraídos das informações de licença da própria Godot. Consulte também a [licença oficial](https://godotengine.org/license/).

A interface utiliza a fonte padrão fornecida pela Godot, sem importar arquivos de fonte para este repositório. As fontes e bibliotecas incluídas na engine mantêm suas próprias licenças, incluindo SIL Open Font License para as fontes correspondentes. Os avisos estão em [GODOT-LICENSE.txt](GODOT-LICENSE.txt) e no [COPYRIGHT.txt da Godot 4.6.3](https://github.com/godotengine/godot/blob/4.6.3-stable/COPYRIGHT.txt).
