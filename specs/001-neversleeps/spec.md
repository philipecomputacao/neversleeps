# Feature Specification: neversleeps

**Feature Branch**: `001-neversleeps`
**Created**: 2026-09-12
**Status**: Draft
**Input**: "Um app que liga e desliga com um clique a trava de sono do MacBook, com as variáveis documentadas e chave liga/desliga, identidade visual no idioma da Apple."

## Contexto

O MacBook Pro M1 (MacBookPro17,1) dorme ao fechar a tampa, interrompendo tarefas longas
do Claude Code. A trava existe (`pmset disablesleep`), mas exige `sudo` e memorização de
comandos. Nenhuma interface do macOS expõe isso.

## User Scenarios & Testing

### User Story 1 - Segurar a tampa com um clique (Priority: P1)

O usuário vai iniciar uma tarefa longa, clica no ícone da barra de menus e liga
"Não dormir ao fechar a tampa". Autentica uma vez. Fecha o MacBook e o trabalho continua.
Ao terminar, clica de novo para desligar.

**Why this priority**: é o motivo de existir do app. Sozinha, esta história já entrega
todo o valor — as demais são conveniência.

**Independent Test**: ligar pelo menu, conferir `pmset -g | grep SleepDisabled` = 1,
fechar a tampa 2 min, abrir e conferir que `pmset -g log` não registrou `Clamshell Sleep`
no intervalo.

**Acceptance Scenarios**:

1. **Given** o sistema com `SleepDisabled 0`, **When** o usuário clica no item da tampa e
   autentica, **Then** `SleepDisabled` passa a `1` e o ícone da barra muda de estado.
2. **Given** `SleepDisabled 1`, **When** o usuário clica de novo e autentica, **Then**
   volta a `0`.
3. **Given** o diálogo de autenticação aberto, **When** o usuário cancela, **Then** nada
   muda no sistema e o menu continua mostrando o estado real, sem erro na tela.
4. **Given** o usuário alterou `disablesleep` pelo terminal, **When** ele abre o menu,
   **Then** o menu mostra o valor novo — o app lê o sistema, nunca um estado próprio.

### User Story 2 - Painel das demais variáveis de energia (Priority: P2)

O usuário abre o menu e vê as variáveis do `pmset` suportadas por esta máquina, cada uma
com nome em português, valor atual e explicação do que faz e do que quebra.

**Why this priority**: é o pedido explícito de "documentar todas as variáveis com chave
liga/desliga", mas o app já é útil sem ela.

**Independent Test**: alterar `powernap` pelo painel e confirmar com `pmset -g custom`.

**Acceptance Scenarios**:

1. **Given** o painel aberto, **When** o usuário alterna uma variável booleana e autentica,
   **Then** `pmset -g custom` reflete o valor novo na fonte de energia selecionada.
2. **Given** uma variável de minutos (`sleep`, `displaysleep`, `disksleep`), **When** o
   usuário escolhe "Nunca", **Then** o valor anterior é guardado e restaurado ao desligar.
3. **Given** uma variável com risco conhecido (`tcpkeepalive`), **When** o usuário vai
   desligá-la, **Then** o app mostra o que isso quebra antes de pedir a senha.

### User Story 3 - Voltar ao estado de fábrica (Priority: P3)

Um item "Restaurar padrões do macOS" devolve tudo ao default, para o usuário nunca ficar
preso a uma configuração que não entende mais.

**Independent Test**: alterar 3 variáveis, restaurar, conferir `pmset -g custom`.

**Acceptance Scenarios**:

1. **Given** variáveis alteradas, **When** o usuário confirma a restauração e autentica,
   **Then** `pmset restoredefaults` roda e `disablesleep` volta a `0`.

### Edge Cases

- **Cancelar a autenticação**: o app não altera nada e não mostra erro. Cancelar é uso
  normal, não falha.
- **Variável não suportada pela máquina**: o app lê `pmset -g cap` e só exibe o que esta
  máquina aceita. Nada de interruptor decorativo que não grava.
- **Escrita aceita mas ignorada pelo sistema**: após gravar, o app relê o valor. Se o valor
  lido não bate com o pedido, ele avisa que o macOS recusou em silêncio, em vez de mostrar
  o interruptor na posição nova.
- **Estado alterado por fora** (terminal, outro app): resolvido relendo o sistema toda vez
  que o menu abre.
- **`disablesleep` ligado e esquecido**: o ícone permanece visivelmente diferente enquanto
  a trava estiver ativa.

## Requirements

### Functional Requirements

- **FR-001**: O app MUST viver na barra de menus, sem ícone na Dock e sem janela principal.
- **FR-002**: O ícone MUST indicar, sem clique, se a trava da tampa está ativa.
- **FR-003**: O app MUST ler o estado real via `pmset -g` e `pmset -g custom` toda vez que
  o menu for aberto, e MUST NOT manter uma cópia do estado como fonte de verdade.
- **FR-004**: O app MUST obter privilégio via diálogo de autenticação do macOS a cada
  alteração, sem instalar regra de `sudoers` e sem helper privilegiado.
- **FR-005**: O app MUST listar somente as variáveis reportadas por `pmset -g cap`.
- **FR-006**: O app MUST permitir escolher a fonte de energia alvo (sempre / tomada /
  bateria) para as variáveis que são por fonte.
- **FR-007**: O app MUST reler e conferir o valor após cada escrita, e avisar quando a
  escrita não teve efeito.
- **FR-008**: O app MUST exibir, para cada variável, uma explicação em português do que ela
  faz e do que ela quebra.
- **FR-009**: O app MUST oferecer "Restaurar padrões do macOS", com confirmação.
- **FR-010**: O app MUST oferecer abrir no login, ligável e desligável pelo próprio menu.
- **FR-011**: O projeto MUST entregar um desinstalador que remove o app e devolve o
  sistema ao padrão.

### Key Entities

- **Ajuste**: uma variável do `pmset`. Atributos: chave, título em PT-BR, explicação,
  aviso de risco, tipo (booleana / minutos / enumerada), escopo (sistema ou por fonte).
- **Estado**: leitura do sistema num instante — mapa fonte → chave → valor, mais
  `SleepDisabled`, que é global.

## Success Criteria

- **SC-001**: Ligar ou desligar a trava da tampa leva no máximo 2 gestos: um clique no
  menu e a autenticação.
- **SC-002**: O usuário identifica se a trava está ativa olhando a barra de menus, sem
  clicar, em menos de 1 segundo.
- **SC-003**: 100% das variáveis exibidas são graváveis nesta máquina — nenhum interruptor
  que não produz efeito.
- **SC-004**: Toda variável exibida tem explicação do efeito e, quando existe, do risco.
- **SC-005**: Após desinstalar, `pmset -g custom` volta ao padrão e nada do app permanece
  no sistema.

## Assumptions

- Máquina alvo: Apple Silicon, macOS 26, usuário administrador. Verificado nesta máquina.
- Uso pessoal e local. O app não é assinado nem notarizado, e não será distribuído.
- `swiftc` das Command Line Tools basta; Xcode completo não é requisito.
- O usuário aceita autenticar a cada mudança — decisão tomada explicitamente, descartando
  a alternativa de regra `sudoers` sem senha.
- `hibernatemode` é gravável nesta máquina, conforme `pmset -g cap`.
