# Notas de manutenção

Leia antes de mexer. Cada item abaixo custou um bug real.

## Estrutura

Swift Package (`swift build`, `swift run verificar`), sem Xcode. O `.app` é montado por script.

| Caminho | O que é |
|---|---|
| `Package.swift` | Dois alvos + testes. Tools 5.9 (modo Swift 5), macOS 14+ |
| `Sources/NeversleepsCore/` | Núcleo sem AppKit, testável: `Modelo` (ajustes, escritas, estado, catálogo), `Parser` (lê a saída do pmset, funções puras), `Sistema` (executa o pmset), `Localizacao` (`t()`/`tf()`), `Amostras` (saídas reais do pmset) |
| `Sources/neversleeps/` | O app: `main` (linha de comando e partida), `Controlador` (ícone, menu, orientação de primeira vez), `Controlador+Teste` (teste da tampa), `Privilegio`, `Prefs`, `Dialogos`, `JanelaAjustes`, `JanelaAjuda`, `JanelaSobre` |
| `Sources/verificar/` | As checagens do núcleo sem framework de teste. Portão do `construir.sh` |
| `Tests/NeversleepsCoreTests/` | Swift Testing. Roda no CI (exige Xcode) |
| `Recursos/` | `gerar-icone.swift`, `en.lproj/Localizable.strings` (chaves em pt-BR, tradução em inglês), `capturas/` (screenshots usados nos READMEs) |
| `docs/` | Site (GitHub Pages, `main:/docs`): `index.html` pt-BR, `en/index.html`, `sitemap.xml`, `robots.txt`, `assets/`. Single-file, sem analytics. O `en` é gerado do pt por substituições: mudou o pt, regenere o en |
| `construir.sh` | Ícone + `swift build -c release` (cache fora do Drive) + bundle + assinatura ad-hoc + instalação. `--sem-instalar` deixa em `dist/` |
| `publicar.sh` | Zip com `ditto`, sha256, atualiza o cask, cria a Release no GitHub |
| `install.sh` | Instalador de uma linha: baixa a release, confere o sha256, remove a quarentena, instala sem sudo |
| `desinstalar.sh` | Remove o app e oferece restaurar os padrões de energia |
| `Casks/` | Cask do Homebrew (tap pessoal) |
| `versao.txt` | Único lugar da versão: script, plist, janela Sobre e release leem daqui |

## Regras que não mudam

1. **Privilégio só pelo diálogo do macOS**, a cada alteração (`NSAppleScript` dentro do processo, para o diálogo levar o nome e o ícone do app). Nunca `sudoers`, nunca helper com root.
2. **O menu é o app.** Só estado e ações. Nada de checklist, tutorial ou "próximo passo" no menu. Orientação acontece uma vez, em diálogos de primeira vez. Ajustes finos vivem numa janela.
3. **Sem rede, sem telemetria.** Nem no app, nem no site.
4. **Sem travessão** em texto, código, commits ou site.

## Armadilhas do código

1. **Nunca cachear o estado do sistema.** A fonte de verdade é o `pmset`, relido em `menuWillOpen`, num timer de 30 s e ao despertar. Um cache faz o ícone mentir quando alguém mexe pelo Terminal.
2. **Toda escrita exige releitura de conferência** de todas as fontes que ela tocou. O macOS aceita e ignora algumas escritas em silêncio; sem o `recarregar()` + conferência em `executarPrivilegiado`, o app vira interruptor decorativo.
3. **`disablesleep` é global.** Vive em `SleepDisabled` no `pmset -g`, não nas seções tomada/bateria. `Estado.confere` e `Estado.encontrado` têm caso especial; sem ele a conferência acusa "não aplicou" numa escrita que deu certo.
4. **`pmset -g cap` ignora `-a/-b/-c`** e reporta sempre a fonte do cabo. A lista de variáveis vem das seções de `pmset -g custom`. Chave ausente numa fonte não vira controle.
5. **Cancelar a autenticação devolve `-128`** em `NSAppleScript.errorNumber`. É uso normal, não erro: o app fica calado.
6. **Janela de app sem Dock abre atrás** da janela da frente. Toda janela usa `activate(ignoringOtherApps: true)` + `orderFrontRegardless()`. Prova sem clicar: build de debug com `--diagnostico-janelas`.
7. **App Nap freia timers com a tela apagada.** O teste da tampa declara `beginActivity(.userInitiated)`; sem isso a pausa do batimento passa de 19 s e reprova um teste que o log aprovou. Limite: 30 s. O log do `pmset` é a testemunha principal; o batimento, a segunda.
8. **Fechar a tampa com a trava ligada não gera "Display is turned off" no log.** Não dependa disso para detectar a tampa.
9. **`XCTest` e `Testing` não existem nas Command Line Tools.** Testes rodam no CI (`macos-15`; o `macos-14` tem Swift 5.10, sem Swift Testing). Localmente, `swift run verificar`.
10. **Sem Developer ID: assinatura ad-hoc.** Sparkle não funciona com ad-hoc (a assinatura muda a cada build e ele recusa a atualização). O caminho da notarização está em `publicar.sh`.
11. **Localização: a chave é o texto em pt-BR.** Todo texto de interface passa por `t()` ou `tf()`; a tradução vive em `Recursos/en.lproj/Localizable.strings`. Texto novo sem entrada aparece em português no sistema em inglês. Conferir antes de publicar: extraia as chaves com `grep -o 't("[^"]*"'` e compare.
12. **Símbolo SF inexistente vira ícone em branco**, sem erro. Ao acrescentar um, confirme que `NSImage(systemSymbolName:)` não devolve `nil`.
13. **Não use sol/lua na barra.** `sun.max` é o glifo de brilho e `moon` é o de Foco, vizinhos na mesma barra. O par é `cup.and.saucer` e `cup.and.saucer.fill`.
14. **Vocabulário é o do macOS em pt-BR:** "repouso", "Modo Pouca Energia", "Despertar para Acesso de Rede", "Abrir no Início da Sessão", "Encerrar". Title Case nos itens, sentence case nos subtítulos. Botões de alerta nomeiam o resultado ("Ligar", "Desligar", "Restaurar"), nunca "Continuar". Sem emoji.
15. **Ligada não é funcionando.** A legenda da trava diz "ainda não testada" até um teste aprovar. O hotspot do iPhone não é legível pelo app e por isso não está no menu: vive na Ajuda.
16. **Instalar não liga nada.** Ao abrir com a trava desligada e nunca testada, o app diz isso e oferece ligar. Ao despertar de um `Clamshell Sleep` com a trava desligada, avisa com o registro do log. Não remova nem enfraqueça.
17. **Depois de mudar qualquer `Sources/**/*.swift`, rode `bash construir.sh`.** O cache do SwiftPM fica em `~/Library/Caches/neversleeps-build`, nunca em `.build/` dentro do Drive. O script mata o processo antigo e espera; sem isso o macOS mantém a versão velha viva.
18. **Verifique com `swift run verificar` e `--estado`**, não com "compilou".
19. **`--desregistrar-login` existe para o `desinstalar.sh`.** Remover o bundle sem chamá-lo deixa um Item de Início de Sessão órfão.
20. **Screenshots nascem do próprio app** (`--capturar <pasta>`, build de debug), sem Gravação de Tela: o macOS deixa capturar janelas do próprio processo, com a moldura e a sombra nativas. A janela do item de status tem `windowNumber` 2^32 e não cabe em `CGWindowID`; o filtro `capturavel` a exclui. O menu é fotografado em rajada durante o rastreamento, porque a primeira foto sai no meio da animação.
21. **`gh repo create --source=.` não segue o `.git` ponteiro** do `--separate-git-dir`. Crie sem `--source` e adicione o remoto à mão.

## Máquina de referência

MacBookPro17,1 (M1), macOS 26.2. `hibernatemode` é gravável aqui. `lessbright` só existe na bateria. `womp` vem 1 na tomada e 0 na bateria.
