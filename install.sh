#!/bin/bash
# =============================================================================
#  neversleeps — instalador de uma linha / one-line installer
#
#    curl -fsSL https://raw.githubusercontent.com/philipecomputacao/neversleeps/main/install.sh | bash
#
#  O QUE FAZ / WHAT IT DOES
#  ------------------------
#  1. Confere macOS 14+ e Apple Silicon ou Intel (o app e universal? nao: arm64).
#  2. Descobre a versao mais recente em GitHub Releases.
#  3. Baixa neversleeps-<versao>.zip e o .sha256, e CONFERE o checksum.
#  4. Extrai com ditto, remove a marca de quarentena (o app nao e notarizado;
#     sem isto o macOS exigiria "botao direito -> Abrir") e copia para
#     /Applications, substituindo a versao anterior.
#  5. Abre o app. O icone (xicara) aparece na barra de menus.
#
#  NAO usa sudo. NAO instala nada alem do .app. Para remover:
#    curl -fsSL https://raw.githubusercontent.com/philipecomputacao/neversleeps/main/desinstalar.sh | bash
#
#  Variaveis opcionais:
#    NEVERSLEEPS_VERSION=1.0.0   instala uma versao especifica em vez da ultima
# =============================================================================
set -euo pipefail

REPO="philipecomputacao/neversleeps"
NOME="neversleeps"
DESTINO="/Applications/${NOME}.app"

say()  { printf '\033[1m==> %s\033[0m\n' "$*"; }
fail() { printf '\033[31mERRO: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "neversleeps e so para macOS."
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MAJOR" -ge 14 ] || fail "precisa de macOS 14 (Sonoma) ou superior; detectado $(sw_vers -productVersion)."
[ "$(uname -m)" = "arm64" ] || fail "a release atual e para Apple Silicon (arm64). Em Intel, compile: git clone e bash construir.sh."
[ -w /Applications ] || fail "sem permissao de escrita em /Applications."
command -v curl >/dev/null || fail "curl nao encontrado."

say "Descobrindo a versao mais recente"
if [ -n "${NEVERSLEEPS_VERSION:-}" ]; then
  TAG="v${NEVERSLEEPS_VERSION#v}"
else
  TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
  [ -n "$TAG" ] || fail "nao consegui ler a versao mais recente em GitHub Releases."
fi
VERSAO="${TAG#v}"
ZIP="${NOME}-${VERSAO}.zip"
BASE="https://github.com/${REPO}/releases/download/${TAG}"
echo "    ${TAG}"

TRABALHO="$(mktemp -d)"
trap 'rm -rf "$TRABALHO"' EXIT
cd "$TRABALHO"

say "Baixando ${ZIP}"
curl -fsSL -o "$ZIP" "${BASE}/${ZIP}" || fail "download falhou: ${BASE}/${ZIP}"
curl -fsSL -o "${ZIP}.sha256" "${BASE}/${ZIP}.sha256" || fail "checksum nao encontrado na release."

say "Conferindo o sha256"
ESPERADO=$(cut -d' ' -f1 < "${ZIP}.sha256")
OBTIDO=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
[ "$ESPERADO" = "$OBTIDO" ] || fail "checksum diferente. Esperado ${ESPERADO}, obtido ${OBTIDO}. Nada foi instalado."
echo "    ok ${OBTIDO:0:12}…"

say "Extraindo"
ditto -x -k "$ZIP" .
[ -d "${NOME}.app" ] || fail "o zip nao contem ${NOME}.app."
# O app e assinado ad-hoc, nao notarizado. Sem esta linha o macOS bloquearia a
# primeira abertura ate voce fazer "botao direito -> Abrir".
xattr -dr com.apple.quarantine "${NOME}.app" 2>/dev/null || true

say "Instalando em /Applications"
if pgrep -qx "$NOME"; then
  pkill -x "$NOME" || true
  for _ in $(seq 1 25); do pgrep -qx "$NOME" || break; sleep 0.2; done
fi
rm -rf "$DESTINO"
ditto "${NOME}.app" "$DESTINO"
open "$DESTINO"

echo
say "Pronto: neversleeps ${VERSAO} instalado."
echo "    Clique na xicara na barra de menus, no alto a direita."
echo "    Xicara vazia = repouso normal · xicara cheia = o Mac nao repousa ao fechar a tampa."
echo
echo "    Ready: click the cup in the menu bar. Empty cup = normal sleep · full cup = the Mac stays awake when closed."
