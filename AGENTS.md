# Notas de manutenção

Leia antes de mexer. Cada item abaixo custou um bug real.

## Estrutura

Swift Package (`swift build`, `swift run verificar`), sem Xcode. O `.app` é montado por script.

| Caminho | O que é |
|---|---|
| `Package.swift` | Dois alvos + testes. Tools 5.9 (modo Swift 5), macOS 14+ |
| `Sources/NeversleepsCore/` | Núcleo sem AppKit, testável: `Modelo` (ajustes, escritas, estado, catálogo), `Parser` (lê a saída do pmset, nvram, fdesetup e ioreg, funções puras), `Sistema` (executa os comandos), `Energia` (Falta de Energia: `PartidaAutomatica`, `Reinicio`, `PeriodoNaBateria`, `Tarefa`), `Registro` (Histórico: `Evento`, `Diario`, `Fita`), `Localizacao` (`t()`/`tf()`), `Amostras` (saídas reais) |
| `Sources/neversleeps/` | O app: `main` (linha de comando e partida), `Controlador` (ícone, menu, orientação de primeira vez), `Controlador+Teste` (teste da tampa), `Controlador+Energia` (reinício inesperado, relato, retomada), `Historico` (anotar, símbolo e cor de cada evento), `Privilegio`, `Prefs`, `Dialogos`, `JanelaAjustes`, `JanelaEnergia`, `JanelaHistorico`, `JanelaAjuda`, `JanelaSobre` |
| `Sources/verificar/` | As checagens do núcleo sem framework de teste. Portão do `construir.sh` |
| `Tests/NeversleepsCoreTests/` | Swift Testing. Roda no CI (exige Xcode) |
| `Recursos/` | `gerar-icone.swift`, `en.lproj/Localizable.strings` (chaves em pt-BR, tradução em inglês), `capturas/` (screenshots usados nos READMEs) |
| `docs/` | Site (GitHub Pages, `main:/docs`): `index.html` pt-BR, `en/index.html`, `sitemap.xml`, `robots.txt`, `assets/`. Single-file, sem analytics. O `en` é gerado do pt por substituições: mudou o pt, regenere o en |
| `construir.sh` | Ícone + `swift build -c release` (cache fora do Drive) + bundle + assinatura ad-hoc + instalação. `--sem-instalar` deixa em `dist/` |
| `publicar.sh` | Zip com `ditto`, sha256, cria a Release no GitHub, atualiza o cask no tap |
| `install.sh` | Instalador de uma linha: baixa a release, confere o sha256, remove a quarentena, instala sem sudo |
| `desinstalar.sh` | Remove o app e oferece restaurar os padrões de energia |
| (tap) | O cask do Homebrew vive no repositório `philipecomputacao/homebrew-neversleeps`; o `publicar.sh` o atualiza pela API a cada release |
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
21. **Homebrew exige `brew trust <tap>` ANTES de `brew tap`** para taps de terceiros: a validação do `tap` recusa carregar o cask de tap não confiável e devolve "invalid syntax in tap". E `depends_on macos:` recebe símbolo (`:sonoma`), não string com `>=`.
22. **`gh repo create --source=.` não segue o `.git` ponteiro** do `--separate-git-dir`. Crie sem `--source` e adicione o remoto à mão.
23. **Com a trava ligada, nem o repouso de emergência passa.** Em `IOPMrootDomain::checkSystemSleepAllowed` (xnu), o teste `userDisabledAllSleep` vem antes da exceção `lowBatteryCondition`. A bateria acaba com tudo rodando. Soltar a trava sozinho quando a carga cai exigiria root sem diálogo (regra 1). O módulo Falta de Energia registra, religa e retoma; não promete salvar o processo.
24. **MacBook não tem `autorestart`.** `pmset -g cap` não lista (M1). Quem liga depois da queda é o `nvram BootPreference` (Apple, suporte 120622, macOS 15+ e chip Apple): ausente = liga com carregador e tampa; `%00` nenhum; `%01` impede só a tampa; `%02` impede só o carregador. Ler não pede senha; a variável ausente faz o `nvram` sair com 1 e dizer "data was not found" no stderr, por isso o `Sistema.rodarCompleto`. O `autorestart` fica no catálogo e só aparece em Mac de mesa.
25. **FileVault para o reinício na tela de desbloqueio**, antes do macOS e antes deste app. No macOS 26 desbloqueia por SSH com o Acesso Remoto ligado; depois para na janela de login (a sessão só abre por Compartilhamento de Tela ou na frente do Mac). Wi-Fi nessa tela só funcionou a partir do 26.5 (relato de terceiros). O app só diagnostica; **nunca** desliga o FileVault.
26. **Acesso Remoto e Compartilhamento de Tela sem senha:** `launchctl print system/<rótulo>` sai com 0 (carregado) ou 113 (não existe). Medido: `com.apple.screensharing` ligado = 0; `com.apple.ftpd` desligado = 113; `com.openssh.sshd` desligado = 113. O caso sshd ligado não foi medido nesta máquina. `systemsetup -getremotelogin` exige admin.
27. **Reinício inesperado = `kern.boottime` mudou e o app não viu o próprio fim.** `applicationWillTerminate` e `willPowerOffNotification` gravam `encerradoNoBoot`. `pkill` (SIGTERM) do `construir.sh` não passa por `willTerminate`, mas o boot é o mesmo, então não acusa. Limite: se o usuário Encerrar o app e o Mac cair depois, nada é acusado.
28. **Avaliar a partida ANTES de registrar a fonte.** `iniciarEnergia()` chama `avaliarPartida()` e só depois `fonteMudou()`; na ordem inversa, o período na bateria da partida anterior é fechado com a hora de agora e a prova some.
29. **Retomada abre `.command` no Terminal**, sem AppleScript: não pede permissão de Automação. O comando é texto livre do usuário e roda como ele; **nunca** passa pelo `Privilegio`. Arquivos em `~/Library/Application Support/neversleeps/retomar/`, recriados a cada retomada. O `~` da pasta é expandido pelo app, porque dentro de aspas simples o shell não expande. Prova sem desligar o Mac: build de debug com `--simular-reinicio`.
30. **O build de debug fora do bundle usa o domínio `neversleeps` do `defaults`**, não `me.lpdigital.neversleeps`. Teste no debug não mexe nas preferências do app instalado.
31. **`pmset -g log` custa 14 s de CPU** (7 dias, 377 mil linhas, 99% assertions e DarkWake); `log show` custa 13 s. Nunca na thread principal, nunca a cada despertar. Só o teste da tampa o lê (testemunha independente), em segundo plano. Todo o resto vem do diário do Histórico.
32. **O Histórico é o diário do app** (`Registro.swift` + `Historico.swift`): `historico.jsonl` em Application Support, uma linha por evento, poda de 30 dias ou 1.000 eventos na partida. É história, não estado: menu e ícone continuam perguntando ao sistema. Todo evento novo entra por `Historico.anotar`, com título e descrição em `Evento` (localizados) e símbolo e cor em `Historico`.
33. **Repouso é anotado no `willSleepNotification`**, com a tampa lida no `ioreg -r -k AppleClamshellState -d 1` (16 ms). DarkWake (manutenção, Power Nap) não chega ao app, então o Histórico não se enche de ruído.
34. **Na partida, `fonteMudou(anotar: false)`**: a partida já anota a fonte (`appAbriu`/`macLigou`/`reinicioInesperado` levam `fonte`). Anotar "saiu da tomada" na abertura seria mentira.
35. **Cores do Histórico só com `NSColor` do sistema em `NSBox`/`draw()`.** `layer.backgroundColor` com `cgColor` congela a cor e quebra o modo escuro. `NSBox` custom não tem tamanho intrínseco: conteúdo preso por constraints (o selo nasceu com altura zero).
36. **Demonstração e capturas do Histórico nunca no diário real:** `NEVERSLEEPS_HISTORICO=<arquivo>` com `--historico-demo` (o demo recusa rodar sem a variável). Modo escuro nas capturas: `--escuro`.
37. **Evento guarda dado, não frase.** Chaves do catálogo, booleanos e contagens; o título e a descrição são montados na hora de mostrar, no idioma de agora. Guardar texto traduzido congelava o idioma do dia da anotação (apareceu "Desligar a Tela Após" no app em inglês). A exceção é `detalhe`, narrativa pronta (relato do reinício, motivo do teste).

## Máquina de referência

MacBookPro17,1 (M1), macOS 26.2. `hibernatemode` é gravável aqui. `lessbright` só existe na bateria. `womp` vem 1 na tomada e 0 na bateria. `BootPreference` ausente, FileVault ligado, Acesso Remoto desligado, Compartilhamento de Tela ligado (29/09/2026).
