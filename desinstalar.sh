#!/bin/bash
# =============================================================================
#  desinstalar.sh — remove o neversleeps e devolve o sistema ao padrao
#  LP Digital (@lpdigital.me) — projetos/neversleeps
# =============================================================================
#
#  O QUE FAZ
#  ---------
#  1. Tira o app dos Itens de Inicio de Sessao (antes de apagar, senao fica orfao)
#  2. Encerra o app, se estiver rodando
#  3. Remove /Applications/neversleeps.app
#  4. Apaga as preferencias do app
#  5. Pergunta se deve restaurar os padroes de energia do macOS
#
#  COMO USAR
#  ---------
#  Passo 1: bash desinstalar.sh
#  Passo 2: responda "s" na pergunta sobre restaurar os padroes, se quiser voltar
#           tudo como era de fabrica
#
#  GOTCHA IMPORTANTE
#  -----------------
#  Desinstalar o app NAO desliga sozinho a trava da tampa. `disablesleep` e uma
#  configuracao do macOS, nao do app: ela sobrevive a remocao e ao reinicio. Por
#  isso o passo 4 existe. Se voce pular, o Mac continua sem dormir de tampa
#  fechada e nao havera mais icone nenhum para avisar disso.
#
#  O passo 1 usa o proprio app (`--desregistrar-login`) para sair dos Itens de
#  Inicio de Sessao. Se mesmo assim sobrar uma entrada, ela fica em
#  Ajustes do Sistema > Geral > Itens de Inicio de Sessao e Extensoes.
# =============================================================================
set -uo pipefail

NOME="neversleeps"
BUNDLE_ID="me.lpdigital.neversleeps"

echo "==> 1/5  Saindo dos Itens de Inicio de Sessao"
BIN="/Applications/${NOME}.app/Contents/MacOS/${NOME}"
if [ -x "$BIN" ]; then "$BIN" --desregistrar-login 2>/dev/null || true; else echo "    app nao encontrado, nada a desregistrar"; fi

echo "==> 2/5  Encerrando o app"
pkill -x "$NOME" 2>/dev/null && echo "    encerrado" || echo "    nao estava rodando"

echo "==> 3/5  Removendo /Applications/${NOME}.app"
if [ -d "/Applications/${NOME}.app" ]; then
  rm -rf "/Applications/${NOME}.app" && echo "    removido"
else
  echo "    nao estava instalado"
fi

echo "==> 4/5  Apagando as preferencias do app"
defaults delete "$BUNDLE_ID" 2>/dev/null && echo "    apagadas" || echo "    nao havia preferencias"

echo "==> 5/5  Estado atual da energia"
pmset -g | grep -i sleepdisabled || true
echo
echo "A trava da tampa e configuracao do macOS e NAO sai com o app."
read -r -p "Restaurar os padroes de energia do macOS agora? [s/N] " resposta
case "$resposta" in
  s|S|sim|Sim)
    if sudo pmset -a disablesleep 0 && sudo pmset restoredefaults; then
      echo
      echo "Restaurado. Conferindo:"
      pmset -g | grep -i sleepdisabled
    else
      echo
      echo "FALHOU: os padroes NAO foram restaurados. Rode a mao:"
      echo "  sudo pmset -a disablesleep 0 && sudo pmset restoredefaults"
    fi
    ;;
  *)
    echo "Nada alterado na energia. Para desfazer depois, rode:"
    echo "  sudo pmset -a disablesleep 0 && sudo pmset restoredefaults"
    ;;
esac
