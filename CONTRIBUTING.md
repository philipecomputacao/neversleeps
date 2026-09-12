# Contribuindo / Contributing

**Português abaixo.**

## English

- **Build:** macOS 14+, Command Line Tools only (`xcode-select --install`). `swift build`, `swift run verificar` (local gate), `bash construir.sh` (bundle + install). Tests in `Tests/` use Swift Testing and run in CI (they need Xcode locally).
- **Read `AGENTS.md` first.** It lists the traps that already bit this project (the lock is global and not in the per-source sections; `pmset -g cap` ignores `-b/-c`; windows open behind without `orderFrontRegardless`; App Nap throttles timers…).
- **UI text** goes through `t("…")` with the Portuguese string as the key, and needs a line in `Recursos/en.lproj/Localizable.strings`.
- **Don't change these decisions** without opening an issue first: authentication through macOS's dialog on every change (no `sudoers`, no privileged helper); the menu is the app, not a tutorial; no network, no telemetry.
- Commits: short, imperative, Portuguese or English. One subject per commit.

## Português

- **Build:** macOS 14+, só as Command Line Tools (`xcode-select --install`). `swift build`, `swift run verificar` (portão local), `bash construir.sh` (bundle + instalação). Os testes em `Tests/` usam Swift Testing e rodam no CI (localmente exigem Xcode).
- **Leia o `AGENTS.md` antes.** Ele lista as armadilhas que já morderam este projeto (a trava é global e não está nas seções por fonte; `pmset -g cap` ignora `-b/-c`; janelas abrem atrás sem `orderFrontRegardless`; App Nap freia timers…).
- **Texto de interface** passa por `t("…")` com a string em português como chave, e precisa de uma linha em `Recursos/en.lproj/Localizable.strings`.
- **Não mude estas decisões** sem abrir uma issue antes: autenticação pelo diálogo do macOS a cada alteração (sem `sudoers`, sem helper privilegiado); o menu é o app, não um tutorial; sem rede, sem telemetria.
- Commits: curtos, no imperativo, em português ou inglês. Um assunto por commit.
