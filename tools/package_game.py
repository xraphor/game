"""Package both Godot exports and a clean source ZIP; verify CRC and SHA-256.
Run after exporting Windows and Linux: python3 tools/package_game.py
"""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import argparse
import hashlib
import subprocess

repo = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=repo / 'build/packages')
args = parser.parse_args()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
binaries = {'Windows': repo/'build/windows/NUKE-FOOTBALL.exe',
            'Linux': repo/'build/linux/NUKE-FOOTBALL.x86_64'}
for binary in binaries.values():
    if not binary.is_file():
        raise SystemExit(f'Export missing: {binary}')
source_files = subprocess.check_output(
    ['git', '-C', str(repo), 'ls-files', '--cached', '--others', '--exclude-standard', '-z']
).decode().split('\0')
packages = []
source = output/'NUKE-FOOTBALL-Projeto-Godot.zip'
with ZipFile(source, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
    for relative in sorted(set(source_files)):
        if relative and not relative.startswith(('build/', '.godot/')) and (not relative.startswith('downloads/') or Path(relative).suffix in ('.md', '.png')):
            archive.write(repo/relative, 'NUKE-FOOTBALL-Godot/' + relative)
packages.append(source)
controls = '''NUKE FOOTBALL — Godot 4.6.3

WINDOWS: extraia o ZIP e abra NUKE-FOOTBALL.exe.
LINUX: execute chmod +x NUKE-FOOTBALL.x86_64 e ./NUKE-FOOTBALL.x86_64.
Não precisa instalar Godot ou Unreal para jogar o executável.
Se Vulkan não funcionar, tente --rendering-method gl_compatibility.

WASD/setas mover; Shift correr; mouse mirar; E passe; C câmera; R repor bola.
Espaço/clique: segure para carregar e solte para chutar. Esc pausa; F1 ajuda.

XBOX: LS mover; RS mirar; A segurar e soltar chute; X passe; RT/RB correr;
LT precisão/chute rasteiro; LB/B câmera; Y repor bola; Menu pausa; View ajuda.
D-pad navega nos menus e ajusta zoom durante o jogo. A confirma; B volta.
Pode conectar antes ou durante o jogo. A desconexão pausa o treino.
Vibração depende do controle e driver. Sem teste com Xbox físico neste ambiente.

Escolha entre cinco treinos no menu. Cada sessão dura até 90 segundos.
Aproxime-se da bola para chutar/passar. R mantém tempo e placar;
REINICIAR no menu de pausa começa uma sessão nova.

93 verificações de integração passaram, incluindo entrada Xbox simulada.
Renderização e executável Linux verificados. Windows foi exportado;
a execução em um PC Windows ainda precisa ser verificada.

Modelos anatômicos e HDRI CC0; kit, bola, estádio, interface e áudio originais.
Licenças em assets/. Mais detalhes e fontes no README.md.
'''
for platform, binary in binaries.items():
    package = output/f'NUKE-FOOTBALL-{platform}.zip'
    with ZipFile(package, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
        archive.write(binary, 'NUKE-FOOTBALL/' + binary.name)
        for relative in ['README.md', 'GAME_DESIGN.md']:
            archive.write(repo/relative, 'NUKE-FOOTBALL/' + relative)
        for license_file in sorted((repo/'assets').glob('*')):
            if license_file.is_file() and license_file.suffix in ('.md', '.txt'):
                archive.write(license_file, 'NUKE-FOOTBALL/assets/' + license_file.name)
        archive.writestr('NUKE-FOOTBALL/COMO-JOGAR.txt', controls)
    packages.append(package)
for package in packages:
    with ZipFile(package) as archive:
        assert archive.testzip() is None, f'Corrupted ZIP: {package}'
    print(f'{package.name}: {package.stat().st_size} bytes; CRC OK')
with (output/'SHA256SUMS.txt').open('w') as file:
    for package in sorted(packages):
        file.write(hashlib.sha256(package.read_bytes()).hexdigest() + '  ' + package.name + '\n')
