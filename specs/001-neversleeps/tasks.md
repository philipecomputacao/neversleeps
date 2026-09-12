# Tasks: neversleeps

**Plan**: `specs/001-neversleeps/plan.md`

## Fase 1 — Fundação

- [x] T001 Criar `projetos/neversleeps/` e `Fontes/`
- [x] T002 `Fontes/main.swift`: camada de leitura (`pmset -g`, `-g custom`, `-g cap`)
- [x] T003 `Fontes/main.swift`: camada de escrita privilegiada via `osascript`, com
      tratamento de cancelamento e releitura de conferência

## Fase 2 — User Story 1 (P1): trava da tampa

- [x] T004 Item de menu da trava, lendo e escrevendo `disablesleep`
- [x] T005 Ícone da barra alternando `sun.max.fill` / `moon.zzz.fill`, template
- [x] T006 Releitura a cada abertura do menu (`menuWillOpen`)
- [x] T007 Verificação manual: ligar, fechar a tampa 2 min, conferir `pmset -g log`

## Fase 3 — User Story 2 (P2): painel das variáveis

- [x] T008 Catálogo declarativo dos ajustes, com título, explicação e aviso em PT-BR
- [x] T009 Filtro por `pmset -g cap` — só entra no menu o que a máquina grava
- [x] T010 Seletor de fonte alvo (sempre / tomada / bateria), persistido
- [x] T011 Booleanas com marca de seleção nativa
- [x] T012 Minutos com "Nunca" e restauração do valor anterior
- [x] T013 `hibernatemode` como submenu 0 / 3 / 25
- [x] T014 Aviso de risco antes de escrever em `tcpkeepalive`

## Fase 4 — User Story 3 (P3): volta ao padrão

- [x] T015 "Restaurar padrões do macOS" com confirmação
- [x] T016 `desinstalar.sh`

## Fase 5 — Acabamento

- [x] T017 `Fontes/gerar-icone.swift` — squircle no molde do macOS
- [x] T018 `construir.sh` — compila, monta o bundle, aplica `LSUIElement`
- [x] T019 "Abrir no login" pelo próprio menu
- [x] T020 `README.md` e `AGENTS.md`
- [x] T021 Compilar, abrir e conferir que o menu reflete o `pmset` real

## Fase 6 — Revisão de código + UX/UI (12/09/2026)

Dois agentes de revisão (código e UX). 3 ALTOS, 8 MÉDIOS, 12 BAIXOS no código;
7 ALTOS, 9 MÉDIOS, 11 BAIXOS na UX. Consolidados em 4 lotes, todos aplicados:

- [x] T022 Aviso da trava só na 1ª vez (`showsSuppressionButton`) — SC-001 volta a valer
- [x] T023 `NSAppleScript` in-process: diálogo diz "neversleeps"; ícone `hourglass` durante
- [x] T024 Barra: `cup.and.saucer` → `.fill` (sol/lua colidiam com brilho e Foco)
- [x] T025 "Tomada e Bateria" lê as duas seções; `.mixed` + etiqueta quando divergem;
      conferência das duas após gravar
- [x] T026 Capacidades derivadas de `pmset -g custom` (o `cap` ignora `-b/-c`)
- [x] T027 Minutos como submenu de presets com etiqueta; fim do "valor anterior"
- [x] T028 Falha de leitura vira estado próprio (`Estado.trava == nil`, ícone de alerta)
- [x] T029 Timer 30 s + `didWakeNotification` conferindo a trava
- [x] T030 Restaurar padrões com `&&` e conferência
- [x] T031 Vocabulário Apple pt-BR, Title Case, subtítulos, botões nomeados, Esc no
      Cancelar, destrutivo em vermelho, sem emoji, seletor de fonte como submenu,
      textos impessoais
- [x] T032 Ícone do app com a xícara, bold, ~58%; guards de contexto e gravação
- [x] T033 `SMAppService.requiresApproval` abre os Ajustes
- [x] T034 `--desregistrar-login` + `desinstalar.sh` chama antes do `rm`
- [x] T035 `construir.sh`: `-w` antes de tudo, espera real pelo processo, `sips` audível,
      README no bundle como LEIA-ME.md
- [x] T036 Miúdos: `-128` exato, pipes drenados, parser tolerante a anotação, código
      morto de `#available`, documentação corrigida
- [x] T037 Primeira abertura abre o próprio menu

## Fase 7 — Clareza do escopo (12/09/2026, feedback do usuário)

O usuário não entendeu "Aplicar em". Primeira tentativa (rótulo "Fonte de Energia" +
aviso de fonte em uso) foi descartada pelo próprio usuário: "não podemos deixar 10% de
fora". Diagnóstico final: o problema é a EXISTÊNCIA de um seletor de modo, não o texto.
Modelo adotado é o dos Ajustes do Sistema atuais da Apple: cada ajuste carrega o escopo.

- [x] T038 Seletor de modo removido; `Prefs.fonte` removido
- [x] T039 Booleanos: submenu Sempre / Só na Tomada / Só na Bateria / Nunca, etiqueta com o estado
- [x] T040 Minutos e enumerados: submenu com três seções nomeadas pelo escopo
- [x] T041 Ajuste presente numa só fonte vira interruptor simples
- [x] T042 `Escrita` (chave, tomada?, bateria?) gera um único comando privilegiado (`&&`)
- [x] T043 Cabeçalho "Energia — o Mac está na <fonte> agora" (`pmset -g batt`)
- [x] T044 Escolha que já está aplicada não pede senha

## Fase 8 — Foco no uso principal (12/09/2026)

Usuário: "ficou claro mas complicou muito; o principal uso é fechar na mochila com o
Claude implementando". Divulgação progressiva: menu principal = trava; painel atrás de
"Mais Ajustes de Energia ›". Documentado no README o que a trava NÃO resolve (hotspot
automático é ajuste de Wi-Fi; calor).

- [x] T045 Painel movido para submenu "Mais Ajustes de Energia"
- [x] T046 README: seção "Mac fechado na mochila" com os 3 problemas e o ajuste de Acesso Pessoal

## Fase 9 — Do zero ao funcionando (12/09/2026)

Usuário: "deixe claro o que precisa ser feito desde a instalação, ensine, e não deixe
ativar e achar que funcionou". Ligada ≠ funcionando.

- [x] T047 Checklist "Pronto para a Mochila?" com 4 itens e etiqueta "n de 4"
- [x] T048 Item 3 (hotspot) abre os Ajustes de Wi-Fi e registra auto-relato datado
- [x] T049 Teste da tampa: batimento 5 s + `pmset -g log` desde o início; veredito na tela
- [x] T050 Legenda da trava: "ainda não testada" / "testada e aprovada <quando>"
- [x] T051 `--repousos <min>` para conferir o leitor de log sem fechar a tampa
- [x] T052 README "Do zero ao funcionando" com a tabela do que o app sabe e do que não sabe

## Fase 10 — O erro real do usuário (12/09/2026)

Usuário fechou a tampa sem ligar a trava; Mac repousou (09:09 Clamshell Sleep). App
correto, orientação falhou: nada dizia que instalar não liga nada.

- [x] T053 Boas-vindas ao abrir com trava desligada e nunca testada: "Instalar não muda nada" + "Ligar a Trava Agora"
- [x] T054 Ao despertar após `Clamshell Sleep` com trava desligada: aviso com o registro do log + "Ligar a Trava Agora" + "Não avisar de novo"
- [x] T055 README e AGENTS registram o caso
- [x] T056 BUG: conferência da trava procurava `disablesleep` nas seções por fonte → alerta falso "Encontrado: ." Corrigido com caso especial em `Estado.confere`/`encontrado`

## Fase 11 — Sem checklist (12/09/2026)

Usuário: "não é assim que fazemos apps. Ele precisa saber o que está pronto e dizer o
que falta, somente."

- [x] T057 Submenu "Pronto para a Mochila?" removido
- [x] T058 `montarProximoPasso`: uma linha, o próximo passo que falta, clicável, com o porquê
- [x] T059 Hotspot vira fluxo de um clique: abre os Ajustes + "Já Configurei"
- [x] T060 Trava diz "pronta para a mochila" quando tudo está feito
- [x] T061 Primeiro teste real APROVADO (2 min 39 s, sem repouso no log). Pausa de 19 s revelou App Nap: `beginActivity(.userInitiated)` durante o teste, limite 30 s

## Fase 12 — Menu é o app (12/09/2026)

Usuário: "isso não precisa ficar no app; não é elegante". Seção "Falta para a mochila"
removida; hotspot removido do app; teste vira item comum do rodapé; oferta única de
teste ao ligar a trava pela primeira vez.

- [x] T062 `montarProximoPasso` removido; "Testar a Tampa…" no rodapé
- [x] T063 Hotspot fora do app (boas-vindas menciona uma vez; Ajuda explica)
- [x] T064 "Trava ligada. Testar agora?" uma única vez (`ofertaTesteVista`)

## Fase 13 — Janela de Ajustes (12/09/2026)

Usuário: "quando seleciono algo o menu continua aberto? seria bom configurar um a um".
Menu do macOS fecha por regra; a resposta certa é a janela de ajustes (padrão dos apps
de barra de menus), que ainda resolve as N autenticações.

- [x] T065 `Fontes/JanelaAjustes.swift`: NSGridView com colunas Tomada / Bateria, popups por célula
- [x] T066 Aplicar único: N `pmset` encadeados por `&&`, uma autenticação, releitura, recusados em vermelho
- [x] T067 Menu: "Ajustes de Energia…" (⌘,) no lugar do submenu; `itemBooleano`/`itemComPresets`/`escolher` removidos
- [x] T068 `construir.sh` compila `Fontes/main.swift Fontes/JanelaAjustes.swift`
- [x] T069 Ajuda vira janela do app (`JanelaAjuda.swift`, ⇧⌘?); README sai do bundle. Usuário: "abrir um documento não é profissional"
- [x] T070 BUG: janelas abriam atrás da janela da frente (ativação cooperativa). `orderFrontRegardless()`; `--diagnostico-janelas` para provar sem clicar

## Fase 14 — Profissionalizar para liberar (12/09/2026)

Decisões: sem Developer ID por ora (documentar botão direito), pt-BR + inglês, MIT,
todas as camadas em ordem.

- [x] T071 `versao.txt` único; LICENSE MIT; CHANGELOG (Keep a Changelog); `.gitignore`
- [x] T072 Swift Package: `NeversleepsCore` (sem AppKit) + app + testes Swift Testing com fixtures reais
- [x] T073 `main.swift` dividido: Controlador, Controlador+Teste, Privilegio, Prefs, Dialogos, Janelas
- [x] T074 Janela Sobre (versão, MIT, links, "sem rede, sem telemetria")
- [x] T075 Info.plist: região pt-BR, localizações, categoria Utilitários
- [x] T076 `--diagnostico-janelas` só em `#if DEBUG`
- [x] T077 Localização en via `t()`/`tf()` + `Recursos/en.lproj`
- [x] T078 `construir.sh` com `swift build`, cache fora do Drive, `--sem-instalar`
- [x] T079 `publicar.sh`: zip `ditto`, sha256, cask, Release com notas do CHANGELOG + instrução Gatekeeper
- [x] T080 Cask Homebrew (tap pessoal) e GitHub Actions
- [x] T081 README em inglês + README.pt-BR
- [x] T082 Repositório público `philipecomputacao/neversleeps` + release v1.0.0
- [ ] T083 (quando houver Developer ID) notarização, Sparkle, cask sem caveat
- [ ] T084 (exige Xcode) ícone no formato do macOS 26
- [ ] T085 (exige o usuário) screenshots reais no README

## Fase 15 — Landing page e Google (12/09/2026)

- [x] T086 GitHub Pages em `main:/docs`: `https://philipecomputacao.github.io/neversleeps/` (pt-BR) e `/en/`
- [x] T087 SEO: título/H1 com a busca real, schema SoftwareApplication (preço 0), OG, hreflang, sitemap, robots
- [x] T088 "Gratuito para sempre" explícito; sem analytics na página
- [ ] T089 Google Search Console: propriedade + tag de verificação (exige a conta do usuário) + envio do sitemap
