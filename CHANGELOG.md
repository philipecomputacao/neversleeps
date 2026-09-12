# Changelog

Todas as mudanças relevantes deste projeto são registradas aqui.
Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/). Versionamento: [SemVer](https://semver.org/lang/pt-BR/).

## [Unreleased]

## [1.0.1], 2026-09-12

### Adicionado
- `install.sh`: instalação em uma linha que baixa a release, confere o sha256, remove a quarentena e instala sem `sudo`.
- `.sha256` publicado junto do zip em cada release.
- Site em `philipecomputacao.github.io/neversleeps` (pt-BR e inglês).
- Templates de issue e PR, `CONTRIBUTING.md`, `SECURITY.md`.

### Corrigido
- Preset "Nunca" aparecia em português no app em inglês.
- Popups da janela Ajustes de Energia cortavam "Memória e Disco (padrão)".
- Legendas com vírgula ou ponto médio no lugar do travessão.

## [1.0.0], 2026-09-12

### Adicionado
- Ícone na barra de menus com a trava da tampa (`pmset disablesleep`): xícara vazia = repouso normal, cheia = trava ligada.
- Teste real da tampa: fecha 1 minuto, o app lê `pmset -g log` e o próprio batimento e dá o veredito.
- Janela **Ajustes de Energia** (⌘,): tomada e bateria lado a lado; várias alterações com uma única autenticação; releitura e marcação do que o macOS recusou.
- Janela **Ajuda** (⇧⌘?) e janela **Sobre**.
- Abrir no início da sessão via `SMAppService`.
- Modos de linha de comando: `--estado`, `--repousos <min>`, `--desregistrar-login`.
- Orientação de primeira vez: aviso ao abrir com a trava desligada; pergunta única "testar agora?" ao ligar; aviso ao despertar de um repouso por tampa fechada com a trava desligada.
- Interface em português do Brasil e inglês, seguindo o idioma do sistema.

### Segurança
- Sem rede, sem telemetria. Privilégio obtido pelo diálogo de autenticação do macOS a cada alteração; nenhuma regra de `sudoers`, nenhum helper privilegiado.
