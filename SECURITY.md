# Segurança / Security

## O que o app faz com privilégio / What the app does with privilege

Toda escrita é `pmset` como root, obtida pelo diálogo de autenticação do próprio macOS a cada alteração. O comando é montado a partir de um catálogo fixo de chaves e de inteiros — nunca de entrada livre. Não há regra de `sudoers`, não há helper privilegiado, nada com root fica no sistema depois do clique.

Every write is `pmset` as root, obtained through macOS's own authentication dialog on each change. The command is built from a fixed catalog of keys and integers — never from free input. No `sudoers` rule, no privileged helper, nothing with root remains on the system after the click.

## Rede / Network

Nenhuma. O app não abre conexões, não tem telemetria, não checa atualizações. / None. The app opens no connections, has no telemetry, does not check for updates.

## Assinatura / Signing

Assinatura ad-hoc, não notarizada (sem Developer ID). O `install.sh` remove a marca de quarentena depois de **conferir o sha256** publicado na release. Se preferir, instale manualmente e use "botão direito → Abrir".

Ad-hoc signed, not notarized (no Developer ID). `install.sh` removes the quarantine flag after **verifying the sha256** published with the release. If you prefer, install manually and use "right-click → Open".

## Reportar / Reporting

Abra uma issue com o rótulo `security`, ou escreva para o contato em [lpdigital.me](https://lpdigital.me). / Open an issue labeled `security`, or write to the contact at [lpdigital.me](https://lpdigital.me).
