# neversleeps — o MacBook não dorme com a tampa fechada

**Rode o Claude Code, um build, um download ou qualquer tarefa longa do terminal com o MacBook fechado, dentro da mochila.** Um app de barra de menus para macOS que liga e desliga a trava de repouso da tampa com um clique — e depois *prova* que funcionou.

[![Release](https://img.shields.io/github/v/release/philipecomputacao/neversleeps?label=release)](https://github.com/philipecomputacao/neversleeps/releases/latest)
[![Build](https://github.com/philipecomputacao/neversleeps/actions/workflows/build.yml/badge.svg)](https://github.com/philipecomputacao/neversleeps/actions/workflows/build.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000?logo=apple)](#instalar)
[![Licença: MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-blue.svg)](LICENSE)

**English:** [README.md](README.md)

## Instalar

Uma linha — baixa a release mais recente, **confere o sha256**, instala em `/Applications` e abre. Sem `sudo`.

```bash
curl -fsSL https://raw.githubusercontent.com/philipecomputacao/neversleeps/main/install.sh | bash
```

<details>
<summary>Outros jeitos</summary>

**Homebrew** (tap pessoal):

```bash
brew tap philipecomputacao/neversleeps https://github.com/philipecomputacao/neversleeps
brew install --cask neversleeps
```

**Manual:** baixe o `.zip` em [Releases](https://github.com/philipecomputacao/neversleeps/releases/latest), descompacte, arraste `neversleeps.app` para Aplicativos. Na primeira abertura, **botão direito → Abrir** (uma vez) — o app ainda não é notarizado pela Apple.

**Compilando** (macOS 14+, só as Command Line Tools, sem Xcode):

```bash
git clone https://github.com/philipecomputacao/neversleeps.git && cd neversleeps && bash construir.sh
```
</details>

## Usar o Claude Code com o MacBook fechado

É a situação para a qual o app foi feito. Três coisas precisam ser verdade, e só a primeira é trabalho do app:

1. **O Mac não pode repousar fechado.** Clique na xícara na barra de menus → **Impedir Repouso ao Fechar a Tampa** → Touch ID. A xícara fica cheia. É o gesto inteiro.
2. **Precisa de internet fechado.** Deixe o iPhone entrar sozinho: *Ajustes do Sistema → Wi-Fi → Acesso Pessoal → Automaticamente*. O Claude Code retenta quando a rede volta.
3. **Calor.** Sessão do Claude Code é leve — o Mac passa o tempo esperando a API. Build pesado ou teste em loop dentro de uma mochila fechada não é.

Depois clique em **Testar a Tampa…**, feche o Mac por um minuto, abra. O app lê o log do sistema (`pmset -g log`) e o próprio batimento e mostra o veredito. Até um teste aprovar, a linha da trava diz *"Ligada · ainda não testada"* — **ligada não é a mesma coisa que provada.**

<!-- screenshot: menu com a xícara, a linha da trava e o item de ajustes -->

## O que ele faz

| Quero | Faço |
|---|---|
| Trabalhar com a tampa fechada | Clique na xícara → **Impedir Repouso ao Fechar a Tampa** |
| Saber se está ligado sem clicar | **Xícara cheia** = trava ligada · **xícara vazia** = repouso normal |
| Ter certeza de que funciona | **Testar a Tampa…** (1 minuto, veredito real) |
| Mudar outros ajustes de energia | **Ajustes de Energia…** (⌘,) — tomada e bateria lado a lado, uma autenticação para tudo |
| Abrir junto com o Mac | **Abrir no Início da Sessão** |
| Desfazer tudo | **Restaurar Padrões de Energia…** |

## Por que não `caffeinate` ou Amphetamine?

- `caffeinate` impede o repouso por *ociosidade*. Fechar a tampa passa por cima — o Mac dorme do mesmo jeito. O neversleeps grava `pmset disablesleep`, o único interruptor que sobrevive à tampa.
- O Amphetamine consegue (Closed-Display Mode), mas é uma opção entre dezenas, e nada diz se segurou de verdade. O neversleeps é um interruptor só, e se testa.
- `sudo pmset -a disablesleep 1` no Terminal funciona — é exatamente o que o app roda. O app acrescenta: estado visível na barra de menus, liga/desliga com um clique, teste real, e um aviso se você fechar o Mac com a trava desligada.

## Como funciona

- **Lê o estado real** com `pmset -g`, `pmset -g custom` e `pmset -g batt` toda vez que o menu abre. Nunca guarda — mude algo no Terminal e o menu conta a verdade.
- **Escreve** com `pmset` como root pelo **diálogo de autenticação do próprio macOS** (Touch ID / senha), uma autenticação por mudança. Sem regra de `sudoers`, sem helper privilegiado, nada com root pendurado.
- **Relê depois de toda escrita.** Se o macOS aceitou o comando mas ignorou o valor, você fica sabendo.
- **Sem rede. Sem telemetria.** Nada sai da sua máquina. ([SECURITY.md](SECURITY.md))

```bash
/Applications/neversleeps.app/Contents/MacOS/neversleeps --estado        # o que o app lê
/Applications/neversleeps.app/Contents/MacOS/neversleeps --repousos 60   # repousos, últimos 60 min
```

## Desinstalar

```bash
curl -fsSL https://raw.githubusercontent.com/philipecomputacao/neversleeps/main/desinstalar.sh | bash
```

**A trava da tampa é ajuste do macOS e não sai com o app.** O desinstalador pergunta se deve restaurar os padrões de energia.

## Desenvolvimento

Swift Package, dois alvos: `NeversleepsCore` (sem AppKit, testado com saídas reais do `pmset`) e o app. `swift build` · `swift run verificar` · `bash construir.sh` · `bash publicar.sh`. Interface em português do Brasil e inglês, seguindo o idioma do sistema. Veja [CONTRIBUTING.md](CONTRIBUTING.md) e [AGENTS.md](AGENTS.md).

Testado em Apple Silicon, macOS 26. Exige macOS 14+.

## Licença

[MIT](LICENSE) — © 2026 LP Digital ([lpdigital.me](https://lpdigital.me))

<sub>Palavras-chave: MacBook fechado não dormir · usar Claude Code com o notebook fechado · macOS impedir repouso tampa fechada · pmset disablesleep barra de menus · alternativa ao caffeinate · keep MacBook awake lid closed</sub>
