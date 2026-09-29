// =============================================================================
//  JanelaHistorico.swift, a janela "Histórico" do neversleeps (⌘Y)
//  LP Digital (@lpdigital.me), projetos/neversleeps
// =============================================================================
//
//  O QUE FAZ
//  ---------
//  Mostra o que aconteceu com o Mac nos ultimos dias, do jeito que um app da
//  Apple mostraria:
//  1. Fita das ultimas 24 horas: tomada, bateria, repouso, desligado. Passar
//     o mouse sobre um trecho diz o que foi e de que hora a que hora.
//  2. Filtro: Tudo, Energia, Trava, Reinicios.
//  3. Lista agrupada por dia, mais recente em cima: simbolo numa bolinha com
//     a cor do tipo, a frase, o detalhe, a hora, e um selo quando ha.
//  4. Rodape: onde fica guardado, Copiar (texto puro) e Apagar Historico.
//
//  DE ONDE VEM
//  -----------
//  Do diario do app (Historico.diario), nunca do `pmset -g log`, que custa
//  14 s de CPU. A janela se redesenha sozinha quando algo e anotado.
//
//  GOTCHAS
//  -------
//  - Cores sao NSColor do sistema pintadas em NSBox/draw(): acompanham o modo
//    escuro. `layer.backgroundColor` com cgColor congelaria a cor da partida.
//  - Tabela com `usesAutomaticRowHeights`: a altura vem do Auto Layout da
//    celula; detalhe longo quebra em ate 4 linhas.
//  - Mesmo padrao das outras janelas: reaproveitada, abre na frente.
// =============================================================================

import Cocoa
import NeversleepsCore

// MARK: - Fita

final class FitaView: NSView, NSViewToolTipOwner {

    var segmentos: [Segmento] = [] { didSet { atualizarDicas(); needsDisplay = true } }
    var de = Date(), ate = Date()
    private let alturaBarra: CGFloat = 22
    private var dicas: [NSView.ToolTipTag: Segmento] = [:]

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: alturaBarra + 18) }
    override var isFlipped: Bool { true }

    private var barra: NSRect { NSRect(x: 0.5, y: 0.5, width: bounds.width - 1, height: alturaBarra) }

    private func x(_ d: Date) -> CGFloat {
        let total = ate.timeIntervalSince(de)
        guard total > 0 else { return barra.minX }
        return barra.minX + barra.width * CGFloat(d.timeIntervalSince(de) / total)
    }

    override func draw(_ dirtyRect: NSRect) {
        let caminho = NSBezierPath(roundedRect: barra, xRadius: 6, yRadius: 6)
        NSGraphicsContext.saveGraphicsState()
        caminho.addClip()
        for s in segmentos {
            let r = NSRect(x: x(s.inicio), y: barra.minY, width: max(1, x(s.fim) - x(s.inicio)), height: barra.height)
            Historico.cor(s.faixa).setFill()
            r.fill()
            if s.faixa == .desligado { hachura(r) }
        }
        NSGraphicsContext.restoreGraphicsState()
        NSColor.separatorColor.setStroke()
        caminho.lineWidth = 0.5
        caminho.stroke()

        // Marcas de hora: 5 rotulos igualmente espacados, o ultimo e "agora".
        let atributos: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.tertiaryLabelColor]
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("j")
        for i in 0...4 {
            let d = de.addingTimeInterval(ate.timeIntervalSince(de) * Double(i) / 4)
            let texto = (i == 4 ? t("agora") : f.string(from: d)) as NSString
            let tam = texto.size(withAttributes: atributos)
            var px = x(d) - tam.width / 2
            px = min(max(px, 0), bounds.width - tam.width)
            texto.draw(at: NSPoint(x: px, y: alturaBarra + 4), withAttributes: atributos)
        }
    }

    private func hachura(_ r: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: r).addClip()
        let linhas = NSBezierPath()
        var px = r.minX - r.height
        while px < r.maxX {
            linhas.move(to: NSPoint(x: px, y: r.maxY))
            linhas.line(to: NSPoint(x: px + r.height, y: r.minY))
            px += 5
        }
        NSColor.systemGray.withAlphaComponent(0.6).setStroke()
        linhas.lineWidth = 1
        linhas.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func atualizarDicas() {
        removeAllToolTips()
        dicas.removeAll()
        for s in segmentos {
            let r = NSRect(x: x(s.inicio), y: barra.minY, width: max(1, x(s.fim) - x(s.inicio)), height: barra.height)
            dicas[addToolTip(r, owner: self, userData: nil)] = s
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        atualizarDicas()
    }

    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        guard let s = dicas[tag] else { return "" }
        let f = DateFormatter()
        f.timeStyle = .short
        return tf("%@: %@ a %@ (%@)", Historico.nome(s.faixa), f.string(from: s.inicio), f.string(from: s.fim),
                  Evento.duracao(Int(s.fim.timeIntervalSince(s.inicio))))
    }
}

// MARK: - Celulas

private final class CelulaEvento: NSTableCellView {
    private let bolinha = NSBox()
    private let icone = NSImageView()
    private let titulo = NSTextField(labelWithString: "")
    private let detalhe = NSTextField(wrappingLabelWithString: "")
    private let hora = NSTextField(labelWithString: "")
    private let selo = NSBox()
    private let textoSelo = NSTextField(labelWithString: "")
    private var larguraDetalhe: NSLayoutConstraint?

    override init(frame: NSRect) {
        super.init(frame: frame)
        bolinha.boxType = .custom
        bolinha.borderWidth = 0
        bolinha.cornerRadius = 14
        bolinha.contentViewMargins = .zero
        bolinha.translatesAutoresizingMaskIntoConstraints = false
        icone.translatesAutoresizingMaskIntoConstraints = false
        icone.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        bolinha.contentView?.addSubview(icone)

        titulo.font = .systemFont(ofSize: 13, weight: .semibold)
        titulo.lineBreakMode = .byTruncatingTail
        detalhe.font = .systemFont(ofSize: 12)
        detalhe.textColor = .secondaryLabelColor
        detalhe.maximumNumberOfLines = 4
        hora.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        hora.textColor = .tertiaryLabelColor
        hora.alignment = .right
        hora.setContentCompressionResistancePriority(.required, for: .horizontal)
        hora.setContentHuggingPriority(.required, for: .horizontal)

        // NSBox custom nao tem tamanho intrinseco: o texto vai preso por
        // constraints, senao o selo nasce com altura zero e sai cortado.
        selo.boxType = .custom
        selo.borderWidth = 0
        selo.cornerRadius = 5
        selo.fillColor = NSColor.systemTeal.withAlphaComponent(0.15)
        selo.contentViewMargins = .zero
        selo.translatesAutoresizingMaskIntoConstraints = false
        textoSelo.font = .systemFont(ofSize: 11, weight: .medium)
        textoSelo.textColor = .systemTeal
        textoSelo.translatesAutoresizingMaskIntoConstraints = false
        selo.contentView?.addSubview(textoSelo)
        if let c = selo.contentView {
            NSLayoutConstraint.activate([
                textoSelo.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 7),
                textoSelo.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -7),
                textoSelo.topAnchor.constraint(equalTo: c.topAnchor, constant: 2),
                textoSelo.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -2),
            ])
        }

        let coluna = NSStackView(views: [titulo, detalhe, selo])
        coluna.orientation = .vertical
        coluna.alignment = .leading
        coluna.spacing = 2
        coluna.setCustomSpacing(6, after: detalhe)
        // A coluna do texto cede espaco; a hora fica sempre na borda direita.
        for v in [coluna, titulo, detalhe] as [NSView] {
            v.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        }
        coluna.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let linha = NSStackView(views: [bolinha, coluna, hora])
        linha.distribution = .fill
        linha.orientation = .horizontal
        linha.alignment = .top
        linha.spacing = 12
        linha.translatesAutoresizingMaskIntoConstraints = false
        addSubview(linha)
        NSLayoutConstraint.activate([
            bolinha.widthAnchor.constraint(equalToConstant: 28),
            bolinha.heightAnchor.constraint(equalToConstant: 28),
            icone.centerXAnchor.constraint(equalTo: bolinha.centerXAnchor),
            icone.centerYAnchor.constraint(equalTo: bolinha.centerYAnchor),
            linha.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            linha.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            linha.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            linha.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func preencher(_ e: Evento, largura: CGFloat) {
        let cor = Historico.cor(e)
        bolinha.fillColor = cor.withAlphaComponent(0.16)
        icone.image = NSImage(systemSymbolName: Historico.simbolo(e), accessibilityDescription: nil)
        icone.contentTintColor = cor
        titulo.stringValue = e.titulo
        let d = e.descricao
        detalhe.stringValue = d
        detalhe.isHidden = d.isEmpty
        let largo = max(200, largura - 28 - 12 - 60 - 36)
        detalhe.preferredMaxLayoutWidth = largo
        titulo.preferredMaxLayoutWidth = largo
        let f = DateFormatter()
        f.timeStyle = .short
        hora.stringValue = f.string(from: e.quando)
        textoSelo.stringValue = e.selo ?? ""
        selo.isHidden = e.selo == nil
        setAccessibilityLabel([e.titulo, d, hora.stringValue].filter { !$0.isEmpty }.joined(separator: ", "))
    }
}

private final class CelulaDia: NSTableCellView {
    private let rotulo = NSTextField(labelWithString: "")
    override init(frame: NSRect) {
        super.init(frame: frame)
        rotulo.font = .systemFont(ofSize: 11, weight: .semibold)
        rotulo.textColor = .secondaryLabelColor
        rotulo.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rotulo)
        NSLayoutConstraint.activate([
            rotulo.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            rotulo.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            rotulo.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func preencher(_ texto: String) { rotulo.stringValue = texto }
}

// MARK: - Janela

final class JanelaHistorico: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {

    private enum Linha { case dia(String), evento(Evento) }

    private let janela: NSWindow
    private let fita = FitaView()
    private let resumoFita = NSTextField(labelWithString: "")
    private let legenda = NSStackView()
    private let filtro = NSSegmentedControl(labels: [t("Tudo"), t("Energia"), t("Trava"), t("Reinícios")],
                                            trackingMode: .selectOne, target: nil, action: nil)
    private let tabela = NSTableView()
    private let rolagem = NSScrollView()
    private let vazio = NSTextField(wrappingLabelWithString: "")
    private let status = NSTextField(labelWithString: "")
    private var linhas: [Linha] = []
    private var eventos: [Evento] = []
    private var jaCentrou = false

    /// Fonte de energia agora, para a fita quando o diario ainda nao sabe.
    var fonteAgora: () -> Fonte? = { nil }

    override init() {
        janela = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 680),
                          styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        super.init()
        janela.title = t("Histórico")
        janela.isReleasedWhenClosed = false
        janela.minSize = NSSize(width: 520, height: 460)
        janela.delegate = self
        janela.setFrameAutosaveName("neversleeps.historico")
        montar()
        NotificationCenter.default.addObserver(self, selector: #selector(mudou), name: Historico.mudou, object: nil)
    }

    // MARK: Montagem

    private func montar() {
        let tituloFita = NSTextField(labelWithString: t("Últimas 24 horas"))
        tituloFita.font = .systemFont(ofSize: 13, weight: .semibold)
        resumoFita.font = .systemFont(ofSize: 11)
        resumoFita.textColor = .secondaryLabelColor
        let cabecalho = NSStackView(views: [tituloFita, NSView(), resumoFita])
        cabecalho.orientation = .horizontal

        fita.translatesAutoresizingMaskIntoConstraints = false

        legenda.orientation = .horizontal
        legenda.spacing = 14
        legenda.distribution = .fill
        legenda.setHuggingPriority(.required, for: .horizontal)
        for f in [Faixa.tomada, .bateria, .repouso, .desligado] {
            legenda.addArrangedSubview(itemLegenda(f))
        }
        // Espaco no fim: as amostras ficam juntas a esquerda, como no esboco.
        let resto = NSView()
        resto.setContentHuggingPriority(.init(1), for: .horizontal)
        legenda.addArrangedSubview(resto)

        filtro.selectedSegment = 0
        filtro.target = self
        filtro.action = #selector(filtrar)
        filtro.segmentStyle = .automatic

        let coluna = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("evento"))
        tabela.addTableColumn(coluna)
        tabela.headerView = nil
        tabela.style = .inset
        tabela.usesAutomaticRowHeights = true
        tabela.selectionHighlightStyle = .none
        tabela.intercellSpacing = NSSize(width: 0, height: 0)
        tabela.backgroundColor = .clear
        tabela.floatsGroupRows = true
        tabela.dataSource = self
        tabela.delegate = self
        tabela.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        rolagem.documentView = tabela
        rolagem.hasVerticalScroller = true
        rolagem.drawsBackground = false
        rolagem.translatesAutoresizingMaskIntoConstraints = false

        vazio.stringValue = t("O histórico começa agora. Cada repouso, cada queda de energia e cada mudança da trava aparece aqui, com a hora e o motivo.")
        vazio.alignment = .center
        vazio.textColor = .secondaryLabelColor
        vazio.translatesAutoresizingMaskIntoConstraints = false

        status.font = .systemFont(ofSize: 11)
        status.textColor = .tertiaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let copiar = NSButton(title: t("Copiar"), target: self, action: #selector(copiar))
        let apagar = NSButton(title: t("Apagar Histórico…"), target: self, action: #selector(apagar))
        for b in [copiar, apagar] { b.controlSize = .small; b.bezelStyle = .rounded }
        let rodape = NSStackView(views: [status, NSView(), copiar, apagar])
        rodape.orientation = .horizontal
        rodape.spacing = 8

        let topo = NSStackView(views: [cabecalho, fita, legenda, filtro])
        topo.orientation = .vertical
        topo.alignment = .leading
        topo.spacing = 8
        topo.setCustomSpacing(4, after: fita)
        topo.setCustomSpacing(16, after: legenda)
        topo.translatesAutoresizingMaskIntoConstraints = false
        rodape.translatesAutoresizingMaskIntoConstraints = false
        let divisoria = NSBox()
        divisoria.boxType = .separator
        divisoria.translatesAutoresizingMaskIntoConstraints = false

        let conteudo = NSView()
        for v in [topo, rolagem, vazio, divisoria, rodape] { conteudo.addSubview(v) }
        NSLayoutConstraint.activate([
            topo.topAnchor.constraint(equalTo: conteudo.topAnchor, constant: 18),
            topo.leadingAnchor.constraint(equalTo: conteudo.leadingAnchor, constant: 20),
            topo.trailingAnchor.constraint(equalTo: conteudo.trailingAnchor, constant: -20),
            cabecalho.widthAnchor.constraint(equalTo: topo.widthAnchor),
            legenda.widthAnchor.constraint(equalTo: topo.widthAnchor),
            fita.widthAnchor.constraint(equalTo: topo.widthAnchor),

            rolagem.topAnchor.constraint(equalTo: topo.bottomAnchor, constant: 6),
            rolagem.leadingAnchor.constraint(equalTo: conteudo.leadingAnchor, constant: 8),
            rolagem.trailingAnchor.constraint(equalTo: conteudo.trailingAnchor, constant: -8),
            rolagem.bottomAnchor.constraint(equalTo: divisoria.topAnchor),

            vazio.centerYAnchor.constraint(equalTo: rolagem.centerYAnchor),
            vazio.centerXAnchor.constraint(equalTo: rolagem.centerXAnchor),
            vazio.widthAnchor.constraint(lessThanOrEqualToConstant: 360),

            divisoria.leadingAnchor.constraint(equalTo: conteudo.leadingAnchor),
            divisoria.trailingAnchor.constraint(equalTo: conteudo.trailingAnchor),
            divisoria.bottomAnchor.constraint(equalTo: rodape.topAnchor, constant: -10),

            rodape.leadingAnchor.constraint(equalTo: conteudo.leadingAnchor, constant: 20),
            rodape.trailingAnchor.constraint(equalTo: conteudo.trailingAnchor, constant: -20),
            rodape.bottomAnchor.constraint(equalTo: conteudo.bottomAnchor, constant: -12),
        ])
        janela.contentView = conteudo
    }

    private func itemLegenda(_ f: Faixa) -> NSView {
        let mini = AmostraLegenda(faixa: f)
        let rotulo = NSTextField(labelWithString: Historico.nome(f))
        rotulo.font = .systemFont(ofSize: 11)
        rotulo.textColor = .secondaryLabelColor
        let s = NSStackView(views: [mini, rotulo])
        s.spacing = 5
        return s
    }

    // MARK: Dados

    private func recarregar() {
        eventos = Historico.diario.ler()
        let agora = Date()
        fita.de = agora.addingTimeInterval(-24 * 3600)
        fita.ate = agora
        fita.segmentos = Fita.segmentos(eventos, de: fita.de, ate: fita.ate, fonteAgora: fonteAgora())
        resumoFita.stringValue = resumo(fita.segmentos)

        let categoria: CategoriaEvento? = [nil, .energia, .trava, .reinicios][max(0, filtro.selectedSegment)]
        let visiveis = eventos.filter { categoria == nil || $0.categoria == categoria }.reversed()
        let dia = DateFormatter()
        dia.doesRelativeDateFormatting = true
        dia.dateStyle = .full
        let cal = Calendar.current
        linhas.removeAll()
        var ultimoDia: Date?
        for e in visiveis {
            let d = cal.startOfDay(for: e.quando)
            if d != ultimoDia { linhas.append(.dia(dia.string(from: e.quando))); ultimoDia = d }
            linhas.append(.evento(e))
        }
        tabela.reloadData()
        vazio.isHidden = !linhas.isEmpty
        if linhas.isEmpty && !eventos.isEmpty {
            vazio.stringValue = t("Nada deste tipo nos últimos 30 dias.")
        } else if eventos.isEmpty {
            vazio.stringValue = t("O histórico começa agora. Cada repouso, cada queda de energia e cada mudança da trava aparece aqui, com a hora e o motivo.")
        }
        status.stringValue = t("Guardado só neste Mac · últimos 30 dias")
    }

    /// "8 h na bateria · 2 h em repouso": o que a fita diz, em palavras.
    private func resumo(_ s: [Segmento]) -> String {
        func soma(_ f: Faixa) -> Int { Int(s.filter { $0.faixa == f }.reduce(0) { $0 + $1.fim.timeIntervalSince($1.inicio) }) }
        var partes: [String] = []
        let b = soma(.bateria), r = soma(.repouso), d = soma(.desligado)
        if b >= 60 { partes.append(tf("%@ na bateria", Evento.duracao(b))) }
        if r >= 60 { partes.append(tf("%@ em repouso", Evento.duracao(r))) }
        if d >= 60 { partes.append(tf("%@ desligado", Evento.duracao(d))) }
        return partes.isEmpty ? "" : partes.joined(separator: " · ")
    }

    @objc private func mudou() {
        if janela.isVisible { recarregar() }
    }

    @objc private func filtrar() { recarregar() }

    // MARK: Tabela

    func numberOfRows(in tableView: NSTableView) -> Int { linhas.count }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        if case .dia = linhas[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch linhas[row] {
        case .dia(let texto):
            let id = NSUserInterfaceItemIdentifier("dia")
            let c = tableView.makeView(withIdentifier: id, owner: self) as? CelulaDia ?? CelulaDia()
            c.identifier = id
            c.preencher(texto)
            return c
        case .evento(let e):
            let id = NSUserInterfaceItemIdentifier("evento")
            let c = tableView.makeView(withIdentifier: id, owner: self) as? CelulaEvento ?? CelulaEvento()
            c.identifier = id
            c.preencher(e, largura: tableView.bounds.width)
            return c
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }

    // MARK: Acoes

    @objc private func copiar() {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("ddMMyyyyHHmm")
        let texto = eventos.reversed().map { $0.linhaTexto(f) }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(texto, forType: .string)
        status.stringValue = eventos.count == 1 ? t("1 acontecimento copiado.") : tf("%d acontecimentos copiados.", eventos.count)
    }

    @objc private func apagar() {
        let (ok, _) = Dialogos.confirmar(
            t("Apagar o histórico?"),
            t("Todos os acontecimentos guardados neste Mac serão apagados. O que acontecer daqui em diante continua sendo registrado."),
            botao: t("Apagar"), destrutivo: true)
        guard ok else { return }
        Historico.diario.apagar()
        recarregar()
    }

    // MARK: Exibicao

    func windowDidBecomeKey(_ notification: Notification) { recarregar() }

    func mostrar() {
        recarregar()
        if !jaCentrou {
            if !janela.setFrameUsingName("neversleeps.historico") { janela.center() }
            jaCentrou = true
        }
        NSApp.activate(ignoringOtherApps: true)
        janela.orderFrontRegardless()
        janela.makeKeyAndOrderFront(nil)
    }
}

/// Quadradinho da legenda, pintado com a mesma cor e hachura da fita.
private final class AmostraLegenda: NSView {
    let faixa: Faixa
    init(faixa: Faixa) {
        self.faixa = faixa
        super.init(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 10).isActive = true
        heightAnchor.constraint(equalToConstant: 10).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 0.5, dy: 0.5)
        let p = NSBezierPath(roundedRect: r, xRadius: 2, yRadius: 2)
        Historico.cor(faixa).setFill()
        p.fill()
        if faixa == .desligado {
            NSGraphicsContext.saveGraphicsState()
            p.addClip()
            let l = NSBezierPath()
            var x: CGFloat = -10
            while x < 10 { l.move(to: NSPoint(x: x, y: 10)); l.line(to: NSPoint(x: x + 10, y: 0)); x += 4 }
            NSColor.systemGray.withAlphaComponent(0.6).setStroke()
            l.stroke()
            NSGraphicsContext.restoreGraphicsState()
        }
        NSColor.separatorColor.setStroke()
        p.lineWidth = 0.5
        p.stroke()
    }
}
