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
#  bash publicar.sh --so-zip   so gera o zip (e o sha256 para o Homebrew)
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

echo "==> Atualizando o cask do Homebrew com versao e sha256"
sed -i '' -E "s/version \"[^\"]+\"/version \"$VERSAO\"/; s/sha256 \"[^\"]+\"/sha256 \"$SHA\"/" Casks/neversleeps.rb

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
echo
echo "Falta: commitar o cask com o sha256 novo:"
echo "  git add Casks/neversleeps.rb && git commit -m \"chore: cask $VERSAO\" && git push"
