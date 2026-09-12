# Implementation Plan: neversleeps

**Spec**: `specs/001-neversleeps/spec.md`
**Data**: 2026-09-12

## Technical Context

| Item | Decisão | Porquê |
|---|---|---|
| Linguagem | Swift 5, AppKit | Único caminho nativo para barra de menus sem dependência externa. `swiftc` já existe nas Command Line Tools. |
| Build | `swiftc` + bundle `.app` montado por script | Sem Xcode, sem projeto `.xcodeproj`, sem assinatura. |
| Privilégio | `NSAppleScript` in-process → `do shell script ... with administrator privileges` | Decisão do usuário: autenticar a cada mudança. Zero alteração no sistema. In-process para o diálogo levar o nome e o ícone do app. |
| Leitura de estado | `pmset -g`, `pmset -g custom`, `pmset -g cap` | Fonte de verdade é o sistema, não o app (FR-003). |
| Persistência | `UserDefaults` apenas para preferências do app | Fonte alvo escolhida e valores anteriores de minutos. Nunca o estado do sistema. |
| Ícone | SF Symbols como imagem template | É o vocabulário visual do macOS; adapta sozinho a claro/escuro e a barra de menus. |

## Identidade visual

Alinhada ao sistema, não a uma marca inventada:

- **Barra de menus**: SF Symbol monocromático com `isTemplate = true`, que é como todo app
  nativo se comporta. `cup.and.saucer` no repouso normal, `cup.and.saucer.fill` com a
  trava ligada — contorno → preenchido é o padrão Apple para "engajado" sem cor.
  (Revisão de 12/09: sol/lua foram descartados porque colidem com brilho e Foco.)
  `hourglass` durante a autenticação; `exclamationmark.triangle` quando o `pmset` não
  pôde ser lido.
- **Menu**: cabeçalhos de seção nativos (`NSMenuItem.sectionHeader`), marcas de seleção do
  próprio AppKit, ícone SF Symbol em cada linha, fonte do sistema por herança. Nenhum
  desenho próprio.
- **Ícone do app**: squircle no molde do macOS (superelipse, não canto arredondado),
  gerado com AppKit (`NSBezierPath`, `NSGradient`) em `Fontes/gerar-icone.swift` e
  empacotado com `iconutil`. Mesmo glifo da barra, em bold para sobreviver a 16 px.
- **Idioma**: PT-BR com o vocabulário do próprio macOS ("repouso", "Modo Pouca Energia",
  "Abrir no Início da Sessão", "Encerrar"), Title Case nos itens, sem jargão de
  terminal na interface. Os nomes técnicos (`disablesleep`, `powernap`) ficam no README
  e nos alertas de falha, para o usuário conseguir procurar depois.

## Constitution Check

Não existe `constitution.md` neste projeto. Aplico as regras da central como substituto:
documentação passo a passo no topo do próprio arquivo, nada de segredo em disco,
`kebab-case` nas pastas, sem `git init` na raiz de `Projetos/`.

## Project Structure

```
projetos/neversleeps/
├── AGENTS.md                  porta de entrada para IAs
├── README.md                  instalação e uso
├── construir.sh               compila e monta neversleeps.app
├── desinstalar.sh             remove o app e restaura padrões
├── Fontes/
│   ├── main.swift             app inteiro, com cabeçalho documentado
│   └── gerar-icone.swift      gera o .icns
└── specs/001-neversleeps/
    ├── spec.md
    ├── plan.md
    └── tasks.md
```

## Decisões de implementação

1. **Catálogo de ajustes é declarativo.** Uma lista de structs descreve cada variável
   (chave, título, explicação, aviso, tipo, escopo). O menu é construído a partir dela, e
   filtrado por `pmset -g cap`. Acrescentar variável no futuro é acrescentar uma linha.
2. **Escrever e conferir.** Toda escrita é seguida de releitura. Divergência vira aviso
   explícito, nunca um interruptor que fingiu funcionar (FR-007).
3. **Cancelar não é erro.** `osascript` devolve `-128` no cancelamento; o app trata como
   "nada a fazer" e fica calado.
4. **Minutos guardam o valor anterior.** Ao ligar "Nunca" em `sleep`/`displaysleep`/
   `disksleep`, o valor corrente vai para `UserDefaults` e volta ao desligar.
5. **`disablesleep` é global.** Não aceita fonte de energia; fica numa seção própria,
   acima das demais, e é o que governa o ícone.

## Riscos

| Risco | Tratamento |
|---|---|
| App não assinado | Uso local apenas. Compilado na máquina, não passa por quarentena de download. Documentado no README. |
| Escrita aceita e ignorada pelo macOS | Releitura obrigatória após cada escrita. |
| `tcpkeepalive 0` derruba Buscar e iMessage | Aviso no menu antes de pedir a senha. |
| Deixar a trava ligada e esquecer | Ícone distinto enquanto ativa. |
| `sleep 1` já presente na máquina | O painel expõe o valor. O app não corrige nada sozinho. |
