#!/bin/bash
# =============================================================================
#  publicar.sh, gera o zip da versao e publica a Release no GitHub
#  LP Digital (@lpdigital.me), MIT
# =============================================================================
#
#  USO
#  ---
#  bash publicar.sh            monta dist/neversleeps-<versao>.zip e cria a
#                              release v<versao> no GitHub com o zip anexado
#  bash publicar.sh --so-zip   so gera o zip e o sha256
#
#  PRE-REQUISITOS
#  --------------
#  - `gh` autenticado (gh auth status)
#  - versao.txt atualizado e CHANGELOG.md com a secao ## [<versao>]
#  - arvore limpa e commitada (a release aponta para o commit atual)
#
#  ASSINATURA E NOTARIZACAO (quando houver Developer ID)
#  -----------------------------------------------------
#  Hoje o app e assinado ad-hoc: em outra maquina o Gatekeeper pede "botao
#  direito -> Abrir" uma vez. Com um Developer ID, troque o codesign de
#  construir.sh por:
#    codesign --force --options runtime --timestamp \
#             --sign "Developer ID Application: SEU NOME (TEAMID)" "$APP"
#  e acrescente aqui, antes de criar a release:
#    xcrun notarytool submit "$ZIP" --keychain-profile "neversleeps" --wait
#    xcrun stapler staple "dist/neversleeps.app"
#  (o perfil se cria uma vez com `xcrun notarytool store-credentials`).
#  So entao o duplo clique funciona em qualquer Mac, o Sparkle passa a ser
#  viavel e o cask do Homebrew deixa de precisar de aviso.
# =============================================================================
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)"

NOME="neversleeps"
VERSAO="$(tr -d '[:space:]' < versao.txt)"
ZIP="dist/${NOME}-${VERSAO}.zip"

echo "==> Conferindo a arvore (a release aponta para o commit atual)"
git diff --quiet && git diff --cached --quiet || { echo "ERRO: ha mudancas nao commitadas. Commite antes de publicar."; exit 1; }
grep -q "^## \[$VERSAO\]" CHANGELOG.md || { echo "ERRO: CHANGELOG.md nao tem a secao ## [$VERSAO]"; exit 1; }

echo "==> Montando o app (versao $VERSAO)"
bash construir.sh --sem-instalar >/dev/null

echo "==> Zip com ditto (preserva a assinatura e os atributos do bundle)"
rm -f "$ZIP"
ditto -c -k --keepParent "dist/${NOME}.app" "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
echo "$SHA  $(basename "$ZIP")" > "${ZIP}.sha256"      # o install.sh confere contra isto
echo "    $ZIP"
echo "    sha256: $SHA"

echo "==> Atualizando a versao no site (schema.org)"
sed -i '' -E "s/\"softwareVersion\": \"[^\"]+\"/\"softwareVersion\": \"$VERSAO\"/" docs/index.html docs/en/index.html

echo "==> Gerando o cask para o tap (philipecomputacao/homebrew-neversleeps)"
CASK="$(mktemp)"
cat > "$CASK" <<CASKEOF
# Cask do neversleeps. Tap: philipecomputacao/neversleeps
#
#   brew tap philipecomputacao/neversleeps
#   brew install --cask neversleeps
#
# Atualizado automaticamente pelo publicar.sh do repositorio principal a cada
# release (versao e sha256). Nao edite a mao.
cask "neversleeps" do
  version "$VERSAO"
  sha256 "$SHA"

  url "https://github.com/philipecomputacao/neversleeps/releases/download/v#{version}/neversleeps-#{version}.zip"
  name "neversleeps"
  desc "Keeps the Mac working with the lid closed (menu bar toggle for pmset disablesleep)"
  homepage "https://philipecomputacao.github.io/neversleeps/"

  depends_on macos: ">= :sonoma"

  app "neversleeps.app"

  uninstall quit: "me.lpdigital.neversleeps"
  zap trash: "~/Library/Preferences/me.lpdigital.neversleeps.plist"

  caveats <<~EOS
    O app ainda nao e notarizado pela Apple. Na primeira abertura:
    clique com o botao direito em neversleeps.app -> Abrir (uma vez).

    The app is not yet notarized by Apple. On first launch:
    right-click neversleeps.app -> Open (once).
  EOS
end
CASKEOF

[ "${1:-}" = "--so-zip" ] && exit 0

NOTAS="$(mktemp)"
awk -v v="$VERSAO" '$0 ~ "^## \\["v"\\]" {f=1; next} /^## \[/ {f=0} f' CHANGELOG.md > "$NOTAS"
cat >> "$NOTAS" <<'EOF'

---

### Instalação em uma linha / One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/philipecomputacao/neversleeps/main/install.sh | bash
```

Baixa, confere o sha256, instala em /Applications e abre. Não usa sudo.
Downloads, verifies the sha256, installs to /Applications and opens. No sudo.

### Manual

1. Baixe o `.zip`, descompacte e arraste `neversleeps.app` para **Aplicativos**. Na primeira abertura, **botão direito → Abrir** (uma vez): o app não é notarizado pela Apple.
2. Download the `.zip`, unzip, drag `neversleeps.app` to **Applications**. First launch: **right-click → Open** (once): the app is not notarized by Apple.
EOF

echo "==> Criando a release v$VERSAO no GitHub"
gh release create "v$VERSAO" "$ZIP" "${ZIP}.sha256" --title "neversleeps $VERSAO" --notes-file "$NOTAS"
rm -f "$NOTAS"
echo "Publicado: $(gh release view "v$VERSAO" --json url -q .url)"

echo "==> Atualizando o cask no tap pela API"
TAP="philipecomputacao/homebrew-neversleeps"
SHA_ATUAL="$(gh api "repos/$TAP/contents/Casks/neversleeps.rb" --jq .sha 2>/dev/null || true)"
gh api -X PUT "repos/$TAP/contents/Casks/neversleeps.rb" \
  -f message="cask neversleeps $VERSAO" \
  -f content="$(base64 < "$CASK" | tr -d '\n')" \
  ${SHA_ATUAL:+-f sha="$SHA_ATUAL"} >/dev/null && echo "    tap atualizado: $TAP"
rm -f "$CASK"
