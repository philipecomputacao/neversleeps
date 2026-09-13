#!/bin/bash
# =============================================================================
#  construir.sh, compila o neversleeps e monta/instala o neversleeps.app
#  LP Digital (@lpdigital.me), MIT
# =============================================================================
#
#  USO
#  ---
#  bash construir.sh                 compila, monta e instala em /Applications
#  bash construir.sh --sem-instalar  compila e monta em dist/neversleeps.app
#
#  O QUE FAZ
#  ---------
#  1. Confere swiftc, versao do macOS e permissao em /Applications (antes de
#     tocar em qualquer coisa)
#  2. Gera a arte do icone (Recursos/gerar-icone.swift) e monta o .icns
#  3. `swift build -c release` (Package.swift), com o cache FORA da pasta do
#     projeto, a pasta e sincronizada pelo Drive, e .build/ tem milhares de
#     arquivos transientes
#  4. Monta o bundle: Info.plist, binario, icone, traducoes (Recursos/*.lproj)
#  5. Assina ad-hoc (necessario para o "Abrir no Inicio da Sessao")
#  6. Instala em /Applications e abre (ou deixa em dist/)
#
#  VERSAO
#  ------
#  A versao vive em UM lugar: versao.txt. Este script grava no Info.plist; a
#  janela Sobre le do plist; publicar.sh usa para nomear a release.
#
#  GOTCHAS
#  -------
#  - Sem Developer ID o app e assinado ad-hoc: abre na maquina que compilou;
#    em outra, o Gatekeeper pede "botao direito -> Abrir" uma vez.
#  - Se o app estiver rodando, o script o encerra e ESPERA o processo sumir.
# =============================================================================
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
cd "$AQUI"

NOME="neversleeps"
BUNDLE_ID="me.lpdigital.neversleeps"
VERSAO="$(tr -d '[:space:]' < versao.txt)"
DESTINO="/Applications/${NOME}.app"
CACHE="${NEVERSLEEPS_CACHE:-$HOME/Library/Caches/neversleeps-build}"
INSTALAR=1
[ "${1:-}" = "--sem-instalar" ] && INSTALAR=0
TRABALHO="$(mktemp -d)"
trap 'rm -rf "$TRABALHO"' EXIT

echo "==> 1/6  Conferindo ferramentas e permissoes (versao $VERSAO)"
command -v swift >/dev/null || { echo "ERRO: swift nao encontrado. Instale as Command Line Tools: xcode-select --install"; exit 1; }
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MAJOR" -ge 14 ] || { echo "ERRO: precisa de macOS 14 ou superior (detectado $(sw_vers -productVersion))"; exit 1; }
if [ "$INSTALAR" = 1 ]; then
  [ -w /Applications ] || { echo "ERRO: sem permissao de escrita em /Applications. Nada foi alterado."; exit 1; }
  if [ -e "$DESTINO" ] && [ ! -w "$DESTINO" ]; then
    echo "ERRO: $DESTINO existe e pertence a outro usuario (instalado com sudo?). Remova-o antes."; exit 1
  fi
fi

echo "==> 2/6  Gerando o icone"
swift Recursos/gerar-icone.swift >/dev/null
ICONSET="$TRABALHO/${NOME}.iconset"
mkdir -p "$ICONSET"
for tamanho in 16 32 64 128 256 512; do
  dobro=$((tamanho * 2))
  sips -z $tamanho $tamanho icone-1024.png --out "$ICONSET/icon_${tamanho}x${tamanho}.png" >/dev/null
  sips -z $dobro $dobro icone-1024.png --out "$ICONSET/icon_${tamanho}x${tamanho}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$TRABALHO/${NOME}.icns"

echo "==> 3/6  Compilando (swift build -c release) e verificando o nucleo"
swift build -c release --scratch-path "$CACHE" 2>&1 | grep -E "error|warning|Build complete" || true
# Portao: as checagens do parser e do modelo, sem framework de teste.
"$CACHE/release/verificar" || { echo "ERRO: a verificacao do nucleo falhou. Nao vou montar o app."; exit 1; }
BIN="$CACHE/release/${NOME}"
[ -x "$BIN" ] || { echo "ERRO: binario nao gerado em $BIN"; exit 1; }

echo "==> 4/6  Montando o bundle"
APP="$TRABALHO/${NOME}.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/${NOME}"
mv "$TRABALHO/${NOME}.icns" "$APP/Contents/Resources/${NOME}.icns"
for lproj in Recursos/*.lproj; do
  [ -d "$lproj" ] && cp -R "$lproj" "$APP/Contents/Resources/"
done

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                <string>${NOME}</string>
    <key>CFBundleDisplayName</key>         <string>${NOME}</string>
    <key>CFBundleIdentifier</key>          <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>          <string>${NOME}</string>
    <key>CFBundleIconFile</key>            <string>${NOME}</string>
    <key>CFBundlePackageType</key>         <string>APPL</string>
    <key>CFBundleShortVersionString</key>  <string>${VERSAO}</string>
    <key>CFBundleVersion</key>             <string>${VERSAO}</string>
    <key>CFBundleDevelopmentRegion</key>   <string>pt-BR</string>
    <key>CFBundleLocalizations</key>
    <array><string>pt-BR</string><string>en</string></array>
    <key>LSMinimumSystemVersion</key>      <string>14.0</string>
    <key>LSApplicationCategoryType</key>   <string>public.app-category.utilities</string>
    <!-- LSUIElement: vive so na barra de menus, sem icone na Dock. -->
    <key>LSUIElement</key>                 <true/>
    <key>NSHumanReadableCopyright</key>    <string>© 2026 LP Digital (lpdigital.me). MIT.</string>
</dict>
</plist>
PLIST

echo "==> 5/6  Assinando (ad-hoc)"
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 || \
  echo "    aviso: nao consegui assinar ad-hoc; o 'Abrir no Inicio da Sessao' pode recusar."

if [ "$INSTALAR" = 0 ]; then
  echo "==> 6/6  Deixando em dist/"
  mkdir -p dist
  rm -rf "dist/${NOME}.app"
  cp -R "$APP" "dist/${NOME}.app"
  echo "Pronto: dist/${NOME}.app (versao $VERSAO)"
  exit 0
fi

echo "==> 6/6  Instalando em /Applications"
if pgrep -qx "${NOME}"; then
  pkill -x "${NOME}" || true
  for _ in $(seq 1 25); do pgrep -qx "${NOME}" || break; sleep 0.2; done
  pgrep -qx "${NOME}" && { echo "ERRO: o ${NOME} antigo nao encerrou. Encerre pelo menu e rode de novo."; exit 1; }
fi
rm -rf "$DESTINO"
cp -R "$APP" "$DESTINO"
open "$DESTINO"
"$DESTINO/Contents/MacOS/${NOME}" --registrar-login 2>/dev/null || true

echo
echo "Pronto (versao $VERSAO). O icone esta na barra de menus, no alto a direita."
echo "  Xicara vazia = repouso normal"
echo "  Xicara cheia = trava ligada, o Mac nao repousa ao fechar a tampa"
