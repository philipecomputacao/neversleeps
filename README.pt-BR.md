# neversleeps

**Mantém o Mac trabalhando com a tampa fechada.** Um app de barra de menus para macOS.

[English](README.md) · [Changelog](CHANGELOG.md) · [MIT](LICENSE)

Feito para uma situação real: você está rodando o Claude Code (ou qualquer tarefa longa no terminal), fecha o MacBook, coloca na mochila — e a tarefa continua, pelo Wi-Fi ou pelo hotspot do iPhone.

<!-- screenshot: menu com a xícara, a linha da trava e o item de ajustes -->

## Instalar

**Baixe** o `neversleeps-<versão>.zip` mais recente em [Releases](https://github.com/philipecomputacao/neversleeps/releases), descompacte e arraste `neversleeps.app` para **Aplicativos**.

**Na primeira abertura, clique com o botão direito → Abrir** (uma vez). O app ainda não é notarizado pela Apple; o macOS avisa na primeira vez e depois não pergunta mais.

Ou pelo Homebrew (tap pessoal):

```bash
brew tap philipecomputacao/neversleeps https://github.com/philipecomputacao/neversleeps
brew install --cask neversleeps
```

Ou compilando (macOS 14+, só as Command Line Tools — não precisa de Xcode):

```bash
git clone https://github.com/philipecomputacao/neversleeps.git
cd neversleeps
bash construir.sh
```

## Usar

| Quero | Faço |
|---|---|
| Trabalhar com a tampa fechada | Clique na xícara → **Impedir Repouso ao Fechar a Tampa** → autentique. A xícara fica cheia. |
| Saber se está ligado sem clicar | **Xícara cheia** = trava ligada. **Xícara vazia** = repouso normal. |
| Ter certeza de que funciona | **Testar a Tampa…** → feche o Mac 1 minuto → abra. O veredito aparece sozinho. |
| Mudar outros ajustes de energia | **Ajustes de Energia…** (⌘,) — tomada e bateria lado a lado, uma autenticação para todas as mudanças. |
| Abrir junto com o Mac | **Abrir no Início da Sessão** |
| Desfazer tudo | **Restaurar Padrões de Energia…** |

**Ligada não é a mesma coisa que provada.** A linha da trava diz *"Ligada · ainda não testada"* até o teste da tampa aprovar. O teste usa duas testemunhas independentes — o log do sistema (`pmset -g log`) e o batimento de 5 segundos do próprio app — e as duas precisam concordar.

### O que a trava não resolve

- **Internet na rua.** Deixe o iPhone entrar sozinho: *Ajustes do Sistema → Wi-Fi → Acesso Pessoal → Automaticamente*. É ajuste do Wi-Fi; o app não controla.
- **Calor.** Sessão do Claude Code é leve (o Mac passa o tempo esperando a rede). Compilação pesada ou testes em loop dentro de uma mochila fechada não são.

## Como funciona

- Lê o estado real com `pmset -g`, `pmset -g custom`, `pmset -g batt` toda vez que o menu abre. Nunca guarda — se você mudar algo no Terminal, o menu conta a verdade.
- Escreve com `pmset` como root pelo **diálogo de autenticação do próprio macOS** (Touch ID / senha), uma autenticação por mudança. Sem regra de `sudoers`, sem helper privilegiado, nada com root pendurado.
- **Relê depois de toda escrita.** Se o macOS aceitou o comando mas ignorou o valor, você fica sabendo.
- **Sem rede. Sem telemetria.** Nada sai da sua máquina.

### Linha de comando

```bash
/Applications/neversleeps.app/Contents/MacOS/neversleeps --estado        # o que o app lê
/Applications/neversleeps.app/Contents/MacOS/neversleeps --repousos 60   # repousos, últimos 60 min
```

## Desinstalar

```bash
bash desinstalar.sh
```

**A trava da tampa é ajuste do macOS e não sai com o app.** O desinstalador pergunta se deve restaurar os padrões de energia; diga sim, a não ser que queira o Mac com a trava.

## Desenvolvimento

```bash
swift build          # compila
swift test           # testes do núcleo (parser, modelo) com saídas reais do pmset
bash construir.sh    # bundle + instalação
bash publicar.sh     # zip + release no GitHub
```

Swift Package, dois alvos: `NeversleepsCore` (sem AppKit, testável) e o app. Interface em português do Brasil e inglês, seguindo o idioma do sistema. Testado em Apple Silicon, macOS 26.

## Licença

[MIT](LICENSE) — © 2026 LP Digital ([lpdigital.me](https://lpdigital.me))
