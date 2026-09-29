// =============================================================================
//  JanelaEnergia.swift, a janela "Falta de Energia" do neversleeps
//  LP Digital (@lpdigital.me), projetos/neversleeps
// =============================================================================
//
//  O QUE FAZ
//  ---------
//  Responde "se a luz cair e a bateria acabar, o que acontece?", em quatro
//  blocos, na ordem em que as coisas acontecem:
//  1. Ligar Sozinho: o BootPreference da NVRAM (MacBook com chip Apple, macOS
//     15 ou superior). Aplicar pede uma autenticacao e rele para conferir.
//  2. Depois de Ligar: diagnostico do FileVault, do Acesso Remoto e do
//     Compartilhamento de Tela. So le; quem liga e desliga e o usuario, nos
//     Ajustes do Sistema.
//  3. Retomar o Trabalho: pastas e comandos que o app reabre no Terminal
//     depois de um reinicio inesperado, e "Retomar Agora" para provar.
//  4. O que aconteceu: o ultimo relato e o ultimo periodo na bateria.
//
//  GOTCHAS
//  -------
//  - Mesmo padrao das outras janelas: AppKit puro, NSStackView, a janela e
//    reaproveitada (`isReleasedWhenClosed = false`), e abre na frente com
//    `activate` + `orderFrontRegardless`.
//  - O comando das tarefas e texto livre do usuario. Roda como ele, pelo
//    Terminal, e NUNCA passa pelo Privilegio.
//  - Mac de mesa nao tem BootPreference: tem o `autorestart`, que aparece em
//    Ajustes de Energia como "Iniciar Após Falta de Energia".
// =============================================================================

import Cocoa
import NeversleepsCore

final class JanelaEnergia: NSObject, NSWindowDelegate, NSTextFieldDelegate {

    /// Chamado depois de aplicar, para o menu e o icone relerem o sistema.
    var aoAplicar: (() -> Void)?
    /// Abre as tarefas no Terminal; devolve as pastas que nao abriram.
    var retomarAgora: (([Tarefa]) -> [String])?

    private let janela: NSWindow
    private let largura: CGFloat = 520
    private var jaCentrou = false

    // 1. Ligar sozinho
    private let caixaCarregador = NSButton(checkboxWithTitle: t("Ligar ao Conectar o Carregador"), target: nil, action: nil)
    private let caixaTampa = NSButton(checkboxWithTitle: t("Ligar ao Abrir a Tampa"), target: nil, action: nil)
    private let notaLigar = NSTextField(wrappingLabelWithString: "")
    private let statusLigar = NSTextField(labelWithString: "")
    private let botaoAplicar = NSButton(title: t("Aplicar…"), target: nil, action: nil)
    private var partida: PartidaAutomatica?

    // 2. Depois de ligar
    private let blocoDepois = NSStackView()

    // 3. Retomar
    private let caixaRetomar = NSButton(checkboxWithTitle: t("Retomar Depois de um Reinício Inesperado"), target: nil, action: nil)
    private let listaTarefas = NSStackView()
    private let statusRetomar = NSTextField(labelWithString: "")
    private let botaoRetomar = NSButton(title: t("Retomar Agora"), target: nil, action: nil)
    private var linhas: [(pasta: String, comando: NSTextField)] = []

    // 4. O que aconteceu
    private let textoUltimo = NSTextField(wrappingLabelWithString: "")

    override init() {
        janela = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 600),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        janela.title = t("Falta de Energia")
        janela.isReleasedWhenClosed = false
        janela.delegate = self
        montar()
    }

    // MARK: Montagem

    private func montar() {
        let intro = rotulo(t("Com a trava ligada, o Mac não repousa nem com a bateria no fim: se a energia cair e a bateria acabar, ele desliga com tudo aberto. Aqui você define o que acontece depois."),
                           secundario: true)

        // 1
        for c in [caixaCarregador, caixaTampa] { c.target = self; c.action = #selector(mudouPartida) }
        notaLigar.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        notaLigar.textColor = .secondaryLabelColor
        notaLigar.preferredMaxLayoutWidth = largura
        pequeno(statusLigar)
        botaoAplicar.target = self; botaoAplicar.action = #selector(aplicarPartida)
        let rodapeLigar = linha([statusLigar, NSView(), botaoAplicar])

        // 2
        blocoDepois.orientation = .vertical
        blocoDepois.alignment = .leading
        blocoDepois.spacing = 8
        let botaoCompart = NSButton(title: t("Abrir Ajustes de Compartilhamento…"), target: self, action: #selector(abrirCompartilhamento))

        // 3
        caixaRetomar.target = self; caixaRetomar.action = #selector(mudouRetomar)
        listaTarefas.orientation = .vertical
        listaTarefas.alignment = .leading
        listaTarefas.spacing = 6
        let botaoAdicionar = NSButton(title: t("Adicionar Pasta…"), target: self, action: #selector(adicionarPasta))
        botaoRetomar.target = self; botaoRetomar.action = #selector(retomar)
        pequeno(statusRetomar)
        let rodapeRetomar = linha([botaoAdicionar, statusRetomar, NSView(), botaoRetomar])
        let explicaRetomar = rotulo(t("Cada tarefa abre numa janela do Terminal, na pasta escolhida. Com “claude --continue”, o Claude Code reabre a última conversa daquela pasta; acrescente uma mensagem entre aspas para ele seguir sozinho, por exemplo: claude --continue \"Continue de onde parou.\""),
                                    secundario: true)

        // 4
        textoUltimo.preferredMaxLayoutWidth = largura
        textoUltimo.isSelectable = true

        let secoes = [t("Ligar Sozinho"), t("Depois de Ligar"), t("Retomar o Trabalho"), t("O Que Aconteceu")].map(secao)
        let pilha = NSStackView(views: [
            intro,
            secoes[0], caixaCarregador, caixaTampa, notaLigar, rodapeLigar,
            secoes[1], blocoDepois, botaoCompart,
            secoes[2], caixaRetomar, listaTarefas, explicaRetomar, rodapeRetomar,
            secoes[3], textoUltimo,
        ])
        pilha.orientation = .vertical
        pilha.alignment = .leading
        pilha.spacing = 10
        pilha.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        pilha.translatesAutoresizingMaskIntoConstraints = false
        // Respiro antes de cada secao, sem separador desenhado.
        for s in secoes {
            if let i = pilha.arrangedSubviews.firstIndex(of: s), i > 0 {
                pilha.setCustomSpacing(22, after: pilha.arrangedSubviews[i - 1])
            }
        }

        let conteudo = NSView()
        conteudo.addSubview(pilha)
        NSLayoutConstraint.activate([
            pilha.topAnchor.constraint(equalTo: conteudo.topAnchor),
            pilha.bottomAnchor.constraint(equalTo: conteudo.bottomAnchor),
            pilha.leadingAnchor.constraint(equalTo: conteudo.leadingAnchor),
            pilha.trailingAnchor.constraint(equalTo: conteudo.trailingAnchor),
            pilha.widthAnchor.constraint(equalToConstant: largura + 40),
            rodapeLigar.widthAnchor.constraint(equalToConstant: largura),
            rodapeRetomar.widthAnchor.constraint(equalToConstant: largura),
        ])
        janela.contentView = conteudo
    }

    private func secao(_ texto: String) -> NSTextField {
        let l = NSTextField(labelWithString: texto)
        l.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        return l
    }

    private func rotulo(_ texto: String, secundario: Bool = false) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: texto)
        l.preferredMaxLayoutWidth = largura
        if secundario {
            l.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            l.textColor = .secondaryLabelColor
        }
        return l
    }

    private func pequeno(_ l: NSTextField) {
        l.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        l.textColor = .secondaryLabelColor
        l.lineBreakMode = .byTruncatingTail
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func linha(_ views: [NSView]) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .horizontal
        s.alignment = .centerY
        s.spacing = 10
        return s
    }

    /// Uma linha de diagnostico: simbolo + texto.
    private func diagnostico(_ simbolo: String, _ texto: String, selecionavel: String? = nil) -> NSView {
        let img = NSImageView(image: NSImage(systemSymbolName: simbolo, accessibilityDescription: nil) ?? NSImage())
        img.contentTintColor = .secondaryLabelColor
        // Largura fixa: cadeado e rede tem larguras diferentes e desalinhavam o texto.
        img.widthAnchor.constraint(equalToConstant: 18).isActive = true
        let l = rotulo(texto)
        l.preferredMaxLayoutWidth = largura - 28
        var coluna: [NSView] = [l]
        if let s = selecionavel {
            let c = NSTextField(labelWithString: s)
            c.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            c.isSelectable = true
            coluna.append(c)
        }
        let v = NSStackView(views: coluna)
        v.orientation = .vertical
        v.alignment = .leading
        v.spacing = 4
        let h = NSStackView(views: [img, v])
        h.orientation = .horizontal
        h.alignment = .top
        h.spacing = 8
        return h
    }

    // MARK: Preenchimento (sempre relendo o sistema)

    private func preencher() {
        preencherPartida(mensagem: nil)
        preencherDepois()
        preencherTarefas()
        preencherUltimo()
        janela.setContentSize(janela.contentView!.fittingSize)
    }

    private var suportaPartida: Bool {
        #if arch(arm64)
        return ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0))
            && Sistema.lerBateria().carga != nil
        #else
        return false
        #endif
    }

    private func preencherPartida(mensagem: String?) {
        partida = suportaPartida ? Sistema.lerPartida() : nil
        let ok = partida != nil
        caixaCarregador.isEnabled = ok
        caixaTampa.isEnabled = ok
        if let p = partida {
            caixaCarregador.state = p.aoConectarCarregador ? .on : .off
            caixaTampa.state = p.aoAbrirTampa ? .on : .off
            notaLigar.stringValue = t("Marcado, um Mac desligado liga ao receber energia do carregador: é assim que ele volta quando a luz volta. É o padrão do macOS em MacBook com chip Apple. Prove uma vez: desligue o Mac, tire o carregador, feche a tampa e conecte de novo.")
        } else if Sistema.lerBateria().carga == nil {
            caixaCarregador.state = .off; caixaTampa.state = .off
            notaLigar.stringValue = t("Este Mac não tem bateria. Em Mac de mesa, o ajuste é “Iniciar Após Falta de Energia”, na janela Ajustes de Energia.")
        } else if !suportaPartida {
            caixaCarregador.state = .off; caixaTampa.state = .off
            notaLigar.stringValue = t("Ligar sozinho ao conectar o carregador exige MacBook com chip Apple e macOS 15 ou superior.")
        } else {
            notaLigar.stringValue = t("Não foi possível ler este ajuste da NVRAM.")
        }
        atualizarRodapeLigar(mensagem: mensagem)
    }

    private var partidaEscolhida: PartidaAutomatica {
        PartidaAutomatica(aoConectarCarregador: caixaCarregador.state == .on, aoAbrirTampa: caixaTampa.state == .on)
    }

    private func atualizarRodapeLigar(mensagem: String?) {
        let pendente = partida != nil && partidaEscolhida != partida
        botaoAplicar.isEnabled = pendente
        if let m = mensagem { statusLigar.stringValue = m }
        else { statusLigar.stringValue = pendente ? t("1 alteração pendente, uma autenticação para aplicar.") : "" }
    }

    private func preencherDepois() {
        blocoDepois.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let fv = Sistema.fileVaultLigado()
        let remoto = Sistema.acessoRemotoLigado()
        let tela = Sistema.compartilhamentoDeTelaLigado()
        let destino = "\(NSUserName())@\(Sistema.nomeLocal() ?? "este-mac").local"

        switch fv {
        case true?:
            blocoDepois.addArrangedSubview(diagnostico("lock.fill",
                t("FileVault ligado: depois de um reinício, o Mac para na tela de desbloqueio, antes de o macOS carregar. Sem desbloquear, nada roda, nem este app.")))
            if remoto == true {
                blocoDepois.addArrangedSubview(diagnostico("network",
                    t("Acesso Remoto ligado: dá para desbloquear de outro aparelho na mesma rede (ou na sua VPN), com a senha deste Mac. No macOS 26 anterior ao 26.5, o Wi-Fi pode não conectar nessa tela; com cabo funciona."),
                    selecionavel: "ssh " + destino))
            } else {
                blocoDepois.addArrangedSubview(diagnostico("network.slash",
                    t("Acesso Remoto desligado: só desbloqueia quem estiver na frente do Mac. Ligue em Compartilhamento para desbloquear de longe por SSH (macOS 26 ou superior).")))
            }
            blocoDepois.addArrangedSubview(diagnostico(tela == true ? "rectangle.on.rectangle" : "rectangle.slash",
                tela == true
                    ? t("Compartilhamento de Tela ligado: o desbloqueio por SSH para na janela de login. Entre por Compartilhamento de Tela para a sessão abrir; aí o app abre e a retomada acontece.")
                    : t("Compartilhamento de Tela desligado: o desbloqueio por SSH para na janela de login, e sem entrar na sessão a retomada não acontece. Ligue em Compartilhamento.")))
        case false?:
            blocoDepois.addArrangedSubview(diagnostico("lock.open",
                t("FileVault desligado: o Mac liga até a janela de login. Com o início de sessão automático ligado em Ajustes do Sistema → Usuários e Grupos, ele entra sozinho e a retomada acontece. Desligar o FileVault deixa os dados expostos se o Mac for perdido; decida com isso em mente.")))
        case nil:
            blocoDepois.addArrangedSubview(diagnostico("questionmark.circle",
                t("Não foi possível ler o estado do FileVault.")))
        }
    }

    private func preencherTarefas() {
        caixaRetomar.state = Prefs.retomarLigado ? .on : .off
        listaTarefas.arrangedSubviews.forEach { $0.removeFromSuperview() }
        linhas.removeAll()
        let tarefas = Prefs.tarefas
        if tarefas.isEmpty {
            listaTarefas.addArrangedSubview(rotulo(t("Nenhuma tarefa. Adicione a pasta de um projeto em que o Claude Code trabalha."), secundario: true))
        }
        for (i, tarefa) in tarefas.enumerated() {
            let pasta = NSTextField(labelWithString: tarefa.pasta)
            pasta.lineBreakMode = .byTruncatingMiddle
            pasta.toolTip = tarefa.pasta
            pasta.widthAnchor.constraint(equalToConstant: 200).isActive = true
            let comando = NSTextField(string: tarefa.comando)
            comando.placeholderString = Tarefa.comandoSugerido
            comando.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            comando.delegate = self
            comando.widthAnchor.constraint(equalToConstant: 260).isActive = true
            let remover = NSButton(image: NSImage(systemSymbolName: "minus.circle", accessibilityDescription: t("Remover")) ?? NSImage(),
                                   target: self, action: #selector(removerTarefa(_:)))
            remover.isBordered = false
            remover.tag = i
            remover.toolTip = t("Remover")
            listaTarefas.addArrangedSubview(linha([pasta, comando, remover]))
            linhas.append((tarefa.pasta, comando))
        }
        atualizarRodapeRetomar(mensagem: nil)
    }

    private func atualizarRodapeRetomar(mensagem: String?) {
        let validas = Prefs.tarefas.filter { $0.valida }.count
        botaoRetomar.isEnabled = validas > 0
        statusRetomar.stringValue = mensagem ?? ""
    }

    private func preencherUltimo() {
        var partes: [String] = []
        if let relato = Prefs.ultimoRelato {
            partes.append(tf("Último reinício inesperado: %@", relato))
        } else {
            partes.append(t("Nenhum reinício inesperado desde que este recurso foi instalado."))
        }
        if let p = Prefs.periodoNaBateria {
            let carga = { (n: Int?) in n.map { "\($0)%" } ?? "?" }
            if let fim = p.fim {
                partes.append(tf("Última vez na bateria: de %@ a %@, %@ → %@.",
                                 Dialogos.quando(p.inicio), Dialogos.quando(fim), carga(p.bateriaInicio), carga(p.ultimaBateria)))
            } else {
                partes.append(tf("Na bateria desde %@, com %@ agora.", Dialogos.quando(p.inicio), carga(p.ultimaBateria)))
            }
        }
        textoUltimo.stringValue = partes.joined(separator: "\n\n")
    }

    // MARK: Acoes

    @objc private func mudouPartida() { atualizarRodapeLigar(mensagem: nil) }

    @objc private func aplicarPartida() {
        let nova = partidaEscolhida
        guard partida != nil, nova != partida else { return }
        statusLigar.stringValue = t("Aguardando a autenticação…")
        botaoAplicar.isEnabled = false
        janela.contentView?.display()

        switch Privilegio.rodar(nova.comando) {
        case .cancelado:
            preencherPartida(mensagem: t("Cancelado. Nada foi alterado."))
        case .falha(let msg):
            preencherPartida(mensagem: tf("Não foi possível aplicar: %@", msg))
        case .ok:
            // Releitura obrigatoria: o que vale e o que a NVRAM diz agora.
            let lida = Sistema.lerPartida()
            preencherPartida(mensagem: lida == nova ? t("Aplicado e conferido no sistema.")
                                                    : t("O macOS aceitou o comando, mas a NVRAM manteve o valor anterior. Os valores mostrados são os reais."))
            aoAplicar?()
        }
    }

    @objc private func abrirCompartilhamento() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sharing-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func mudouRetomar() {
        Prefs.retomarLigado = caixaRetomar.state == .on
        aoAplicar?()
    }

    @objc private func adicionarPasta() {
        let painel = NSOpenPanel()
        painel.canChooseDirectories = true
        painel.canChooseFiles = false
        painel.allowsMultipleSelection = false
        painel.prompt = t("Adicionar")
        painel.message = t("Escolha a pasta do projeto. O app abre o Terminal nela depois de um reinício inesperado.")
        NSApp.activate(ignoringOtherApps: true)
        guard painel.runModal() == .OK, let url = painel.url else { return }
        let pasta = (url.path as NSString).abbreviatingWithTildeInPath
        var tarefas = Prefs.tarefas
        guard !tarefas.contains(where: { $0.pasta == pasta }) else { return }
        tarefas.append(Tarefa(pasta: pasta, comando: Tarefa.comandoSugerido))
        Prefs.tarefas = tarefas
        preencherTarefas()
        janela.setContentSize(janela.contentView!.fittingSize)
        aoAplicar?()
    }

    @objc private func removerTarefa(_ sender: NSButton) {
        var tarefas = Prefs.tarefas
        guard tarefas.indices.contains(sender.tag) else { return }
        tarefas.remove(at: sender.tag)
        Prefs.tarefas = tarefas
        preencherTarefas()
        janela.setContentSize(janela.contentView!.fittingSize)
        aoAplicar?()
    }

    /// Salva a cada tecla: fechar a janela no meio da edicao nao perde nada.
    func controlTextDidChange(_ obj: Notification) {
        Prefs.tarefas = linhas.map { Tarefa(pasta: $0.pasta, comando: $0.comando.stringValue) }
        atualizarRodapeRetomar(mensagem: nil)
    }

    @objc private func retomar() {
        let tarefas = Prefs.tarefas.filter { $0.valida }
        guard !tarefas.isEmpty, let abrir = retomarAgora else { return }
        let falharam = abrir(tarefas)
        atualizarRodapeRetomar(mensagem: falharam.isEmpty
            ? (tarefas.count == 1 ? t("1 tarefa aberta no Terminal.") : tf("%d tarefas abertas no Terminal.", tarefas.count))
            : tf("Não abriram: %@.", falharam.joined(separator: ", ")))
    }

    // MARK: Exibicao

    func mostrar() {
        preencher()
        if !jaCentrou { janela.center(); jaCentrou = true }
        NSApp.activate(ignoringOtherApps: true)
        janela.orderFrontRegardless()
        janela.makeKeyAndOrderFront(nil)
    }
}
