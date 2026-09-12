# AGENTS.md — neversleeps

Porta de entrada para IAs. **Leia antes de tocar em qualquer arquivo.**

## O que é

App de barra de menus (Swift + AppKit) que liga/desliga `pmset disablesleep` e outras
variáveis de energia do macOS. Uso pessoal, local, não distribuído.

## Estrutura

Swift Package (`swift build`, `swift test`), sem Xcode. O `.app` é montado por script.

| Caminho | O que é |
|---|---|
| `Package.swift` | Dois alvos + testes. Tools 5.9 (modo Swift 5), macOS 14+ |
| `Sources/NeversleepsCore/` | Núcleo **sem AppKit**, testável: `Modelo` (ajustes, escritas, estado, catálogo), `Parser` (lê a saída do pmset, funções puras), `Sistema` (executa o pmset), `Localizacao` (`t()`/`tf()`) |
| `Sources/neversleeps/` | O app: `main` (CLI + partida), `Controlador` (ícone, menu, orientação), `Controlador+Teste` (teste da tampa), `Privilegio`, `Prefs`, `Dialogos`, `JanelaAjustes`, `JanelaAjuda`, `JanelaSobre` |
| `Tests/NeversleepsCoreTests/` | Swift Testing. `Fixtures.swift` tem saídas **reais** do pmset desta máquina |
| `Recursos/` | `gerar-icone.swift` e `en.lproj/Localizable.strings` (chaves em pt-BR → inglês) |
| `construir.sh` | Ícone + `swift build -c release` (cache fora do Drive) + bundle + assinatura ad-hoc + instalação. `--sem-instalar` deixa em `dist/` |
| `publicar.sh` | Zip com `ditto`, sha256, atualiza o cask, cria a Release no GitHub |
| `desinstalar.sh` | Remove o app e oferece restaurar os padrões |
| `Casks/` | Cask para tap pessoal |
| `.github/workflows/build.yml` | CI: `swift test` + bundle em macOS limpo |
| `versao.txt` | **Único** lugar da versão: script → plist → janela Sobre → release |
| `specs/001-neversleeps/` | spec / plan / tasks (spec-kit) |

## Gotchas fatais

1. **Nunca cachear o estado do sistema.** A fonte de verdade é o `pmset`, relido em
   `menuWillOpen`, num timer de 30 s e ao despertar. Um cache faz o ícone mentir quando
   o usuário mexe pelo Terminal. Isso é requisito (FR-003), não estilo.
2. **Toda escrita exige releitura de conferência de TODAS as fontes alvo.** O macOS
   aceita e ignora algumas escritas em silêncio. Sem o `recarregar()` + `conferir` em
   `executarPrivilegiado`, o app vira um interruptor decorativo.
3. **`pmset -g cap` ignora `-a/-b/-c`** e sempre reporta a fonte do cabo. Por isso a
   lista de variáveis vem das seções de `pmset -g custom` (`Estado.tomada` /
   `Estado.bateria`), nunca do `cap`. Uma chave ausente na fonte alvo não vira item.
4. **Cancelar autenticação devolve `-128`** em `NSAppleScript.errorNumber` e é tratado
   como `.cancelado`. Não transforme em erro na tela — cancelar é uso normal.
   A escrita usa `NSAppleScript` **dentro do processo** de propósito: é o que faz o
   diálogo dizer "neversleeps deseja fazer alterações". Trocar por `osascript` em
   subprocesso faz o diálogo dizer "osascript" com ícone genérico.
5. **`disablesleep` é global**, não aceita `-b`/`-c` de forma significativa. Fica com
   `escopo: .sistema` e sempre usa `-a`.
6. **Depois de mudar qualquer `Sources/**/*.swift`, rode `bash construir.sh`.** O cache do
   SwiftPM fica em `~/Library/Caches/neversleeps-build`, nunca em `.build/` dentro do Drive. O script mata o processo
   antigo antes de copiar; sem isso o macOS mantém a versão velha viva e você jura que
   o build não pegou.
7. **Verifique com `swift test` e `--estado`**, não com "compilou":
   `/Applications/neversleeps.app/Contents/MacOS/neversleeps --estado`
8. **Símbolo SF inexistente vira ícone em branco, sem erro.** Ao acrescentar um,
   confirme que `NSImage(systemSymbolName:)` não devolve `nil` nesta versão do macOS.
9. **Vocabulário é o do macOS em pt-BR**: "repouso", "Modo Pouca Energia", "Despertar
   para Acesso de Rede", "Abrir no Início da Sessão", "Encerrar". Title Case nos itens,
   sentence case nos subtítulos. Botões de alerta nomeiam o resultado ("Ligar",
   "Desligar", "Restaurar"), nunca "Continuar". Sem emoji.
10. **Não use sol/lua na barra**: `sun.max` é o glifo de brilho e `moon` é o de Foco,
    que fica ao lado. O par é `cup.and.saucer` → `cup.and.saucer.fill`.
11. **`--desregistrar-login` existe para o `desinstalar.sh`.** Remover o bundle sem
    chamá-lo deixa um Item de Início de Sessão órfão.
12. **Não existe seletor de modo, e não deve voltar a existir.** O usuário real não
    entendeu "Aplicar em" (uma escolha global mudando o significado de todos os itens).
    Cada item carrega o próprio escopo: booleanos com 4 estados (Sempre / Só na Tomada /
    Só na Bateria / Nunca), minutos e enumerados com três seções nomeadas. A `Escrita`
    viaja inteira no `representedObject` ("chave|t|b") — não há estado escondido entre
    abrir o menu e clicar. O cabeçalho mostra `Estado.emUso` (`pmset -g batt`).
13. **O menu principal é a trava e só.** O painel de energia vive atrás de "Mais Ajustes
    de Energia ›". O uso real é "fechar o Mac na mochila com o Claude rodando"; tudo
    que competir com a primeira linha por atenção é regressão.
14. **O menu é o app, não um tutorial.** O usuário rejeitou o checklist ("não é assim
    que fazemos apps") e depois a seção "próximo passo" ("não é elegante"). Regra: no
    menu só ESTADO e AÇÕES comuns. Orientação acontece uma vez, em diálogos de
    primeira vez (`mostrarBoasVindas`, oferta de teste ao ligar a trava, aviso
    pós-repouso). O hotspot do iPhone **saiu do app** (não é legível) e vive na Ajuda.
    A legenda da trava diz "ainda não testada" até um teste aprovar.
18. **Ajustes finos vivem numa janela, não no menu.** Menu fecha a cada escolha e cada
    escolha pedia Touch ID. `JanelaAjustes` aplica N mudanças com UM comando (`&&`) e
    UMA autenticação, relê o sistema e marca em vermelho o que foi recusado. Não
    recrie submenus de configuração no menu.
19. **Ajuda é janela do app, não arquivo aberto no editor.** O usuário rejeitou o README
    abrindo no TextEdit ("não está profissional"). O README não vai mais no bundle.
20. **Janela de app sem Dock abre ATRÁS.** `NSApp.activate()` sem `ignoringOtherApps`
    é negado pela ativação cooperativa do macOS 14+; o usuário viu "nada abriu". Toda
    janela usa `activate(ignoringOtherApps: true)` + `orderFrontRegardless()`. Prova sem
    clicar: `neversleeps --diagnostico-janelas` imprime frame e visibilidade.
15. **Instalar não liga nada, e o usuário real assumiu que ligava.** Fechou a tampa sem
    clicar em nada e o Mac repousou (log 09:09 `Clamshell Sleep`, `SleepDisabled 0`).
    Por isso existem `mostrarBoasVindas()` (trava desligada e nunca testada) e
    `despertouDoRepouso()` (ao despertar, se houve `Clamshell` nos últimos 15 min com a
    trava desligada). Os dois levam direto ao Touch ID. Não remova nem enfraqueça.
16. **`disablesleep` não está nas seções tomada/bateria.** Ela é global (`SleepDisabled`
    em `pmset -g`). `Estado.confere` e `Estado.encontrado` têm caso especial para ela.
    Sem isso, a conferência diz "não aplicou" para uma escrita que deu certo — foi
    exatamente o alerta falso que o usuário viu em 12/09.
17. **App Nap freia o batimento do teste.** Primeiro teste real: 19 s de pausa num limite
    de 20 s, com o log provando que não houve repouso. `iniciarTeste` chama
    `beginActivity(.userInitiated)` e `encerrarTeste` fecha; limite 30 s. O log do
    `pmset` é a testemunha principal; o batimento é a segunda.

## Máquina de referência

MacBookPro17,1 (M1), macOS 26.2. `hibernatemode` é gravável aqui. `lessbright` só
existe na bateria.
21. **Localização: a chave É o texto em pt-BR.** Todo texto de interface passa por `t("…")`
    ou `tf("… %@ …", args)`. A tradução vive em `Recursos/en.lproj/Localizable.strings`.
    Texto novo sem entrada no `.strings` aparece em português no sistema em inglês —
    rode a extração (`grep -o 't("[^"]*"'`) e compare antes de publicar.
22. **`XCTest` não existe nas Command Line Tools.** Os testes usam Swift Testing
    (`import Testing`, `@Test`, `#expect`). Não converta de volta.
23. **Sem Developer ID: ad-hoc + "botão direito → Abrir".** Sparkle NÃO funciona com
    assinatura ad-hoc (a assinatura muda a cada build e ele recusa a atualização).
    O caminho para notarização está documentado em `publicar.sh`.
