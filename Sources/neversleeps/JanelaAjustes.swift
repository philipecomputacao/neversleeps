// =============================================================================
//  JanelaAjustes.swift, a janela "Ajustes de Energia" do neversleeps
//  LP Digital (@lpdigital.me), projetos/neversleeps
// =============================================================================
//
//  O QUE FAZ
//  ---------
//  A janela onde se configura tomada e bateria LADO A LADO, mexendo em quantos
//  ajustes quiser e aplicando tudo com UMA autenticacao. E o padrao dos apps de
//  barra de menus: o menu e para o gesto rapido (a trava); a janela e para
//  configurar. Menu do macOS fecha a cada escolha, e cada escolha pedia Touch ID,
//  configurar dez coisas custava dez autenticacoes. Aqui custa uma.
//
//  COMO FUNCIONA
//  -------------
//  1. Ao abrir, le o sistema (`Sistema.ler()`) e preenche os popups.
//  2. Cada popup alterado vira uma "alteracao pendente"; o rodape conta.
//  3. "Aplicar..." monta UM comando privilegiado com todos os `pmset` encadeados
//     por && e pede a autenticacao uma vez.
//  4. Depois de aplicar, RELE o sistema e compara: o que o macOS recusou fica
//     marcado em vermelho e nomeado no rodape. Nada e assumido.
//  5. "Reverter" descarta o que ainda nao foi aplicado.
//
//  O QUE NAO ESTA AQUI
//  -------------------
//  A trava da tampa (disablesleep). Ela e global, e a razao do app, e mora na
//  primeira linha do menu. Uma janela de ajustes finos nao deve competir com ela.
//
//  GOTCHAS
//  -------
//  - Construida em AppKit puro, sem Interface Builder: e um NSGridView dentro de
//    um NSStackView. Para acrescentar uma coluna ou linha, mexa em `montar()`.
//  - `isReleasedWhenClosed = false`: a janela e reaproveitada; fechar so esconde.
//  - A escrita e sincrona na thread principal (NSAppleScript). Enquanto o dialogo
//    de senha esta aberto, a janela nao responde, o rodape avisa antes.
// =============================================================================

import Cocoa
import NeversleepsCore

final class JanelaAjustes: NSObject, NSWindowDelegate {

    private struct Linha {
        let ajuste: Ajuste
        let titulo: NSTextField
        let tomada: NSPopUpButton?
        let bateria: NSPopUpButton?
    }

    private let janela: NSWindow
    private let onde = NSTextField(labelWithString: "")
    private let status = NSTextField(labelWithString: "")
    private let grade = NSGridView(numberOfColumns: 3, rows: 0)
    private let botaoAplicar = NSButton(title: t("Aplicar…"), target: nil, action: nil)
    private let botaoReverter = NSButton(title: t("Reverter"), target: nil, action: nil)
    private var linhas: [Linha] = []
    private var estado = Estado()
    private var jaCentrou = false

    /// Chamado depois de aplicar, para o menu/icone relerem o sistema.
    var aoAplicar: (() -> Void)?

    override init() {
        janela = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        janela.title = t("Ajustes de Energia")
        janela.isReleasedWhenClosed = false
        janela.delegate = self
        montar()
    }

    // MARK: Montagem

    private func montar() {
        onde.font = .systemFont(ofSize: NSFont.systemFontSize)
        onde.textColor = .secondaryLabelColor

        grade.rowSpacing = 10
        grade.columnSpacing = 18
        grade.column(at: 0).xPlacement = .leading
        grade.column(at: 1).xPlacement = .fill
        grade.column(at: 2).xPlacement = .fill

        // Cabecalho das colunas: e o que responde "isto vale onde?".
        let cab0 = NSTextField(labelWithString: "")
        let cab1 = NSTextField(labelWithString: t("Tomada"))
        let cab2 = NSTextField(labelWithString: t("Bateria"))
        for c in [cab1, cab2] { c.font = .boldSystemFont(ofSize: NSFont.systemFontSize); c.alignment = .center }
        grade.addRow(with: [cab0, cab1, cab2])

        status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byWordWrapping
        status.maximumNumberOfLines = 2
        status.preferredMaxLayoutWidth = 360

        botaoAplicar.target = self; botaoAplicar.action = #selector(aplicar)
        botaoAplicar.keyEquivalent = "\r"
        botaoReverter.target = self; botaoReverter.action = #selector(reverter)

        let rodape = NSStackView(views: [status, NSView(), botaoReverter, botaoAplicar])
        rodape.orientation = .horizontal
        rodape.alignment = .centerY
        rodape.spacing = 10
        rodape.setHuggingPriority(.defaultLow, for: .horizontal)

        let pilha = NSStackView(views: [onde, grade, rodape])
        pilha.orientation = .vertical
        pilha.alignment = .leading
        pilha.spacing = 16
        pilha.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        pilha.translatesAutoresizingMaskIntoConstraints = false

        let conteudo = NSView()
        conteudo.addSubview(pilha)
        NSLayoutConstraint.activate([
            pilha.topAnchor.constraint(equalTo: conteudo.topAnchor),
            pilha.bottomAnchor.constraint(equalTo: conteudo.bottomAnchor),
            pilha.leadingAnchor.constraint(equalTo: conteudo.leadingAnchor),
            pilha.trailingAnchor.constraint(equalTo: conteudo.trailingAnchor),
            rodape.widthAnchor.constraint(equalTo: pilha.widthAnchor, constant: -40),
        ])
        janela.contentView = conteudo
    }

    private func opcoes(_ a: Ajuste, atual: Int?) -> [(valor: Int, titulo: String)] {
        switch a.tipo {
        case .booleana:
            return [(1, t("Ligado")), (0, t("Desligado"))]
        case .minutos:
            var lista = Catalogo.presetsMinutos
            if let n = atual, n != 0, !lista.contains(n) { lista.append(n); lista.sort() }
            return lista.map { ($0, rotuloMinutos($0)) } + [(0, t("Nunca"))]
        case .enumerada(let ops):
            return ops
        }
    }

    private func popup(_ a: Ajuste, atual: Int?) -> NSPopUpButton {
        let p = NSPopUpButton(frame: .zero, pullsDown: false)
        for o in opcoes(a, atual: atual) {
            p.addItem(withTitle: o.titulo)
            p.lastItem?.tag = o.valor
        }
        if let n = atual { p.selectItem(withTag: n) }
        p.target = self
        p.action = #selector(mudou)
        p.widthAnchor.constraint(equalToConstant: 230).isActive = true   // "Memória e Disco (padrão)" precisa caber
        return p
    }

    /// Reconstroi as linhas a partir do estado. Chamado ao abrir e apos aplicar,
    /// porque o conjunto de chaves e os valores fora dos presets podem mudar.
    private func preencher() {
        while grade.numberOfRows > 1 { grade.removeRow(at: 1) }
        linhas.removeAll()

        for a in Catalogo.ajustes {
            let t = estado.tomada[a.chave], b = estado.bateria[a.chave]
            if t == nil && b == nil { continue }

            let titulo = NSTextField(labelWithString: a.titulo)
            let sub = NSTextField(labelWithString: a.subtitulo)
            sub.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            sub.textColor = .secondaryLabelColor
            let bloco = NSStackView(views: a.subtitulo.isEmpty ? [titulo] : [titulo, sub])
            bloco.orientation = .vertical
            bloco.alignment = .leading
            bloco.spacing = 1

            let pt = t.map { popup(a, atual: $0) }
            let pb = b.map { popup(a, atual: $0) }
            let celT: NSView = pt ?? tracinho()
            let celB: NSView = pb ?? tracinho()
            grade.addRow(with: [bloco, celT, celB])
            linhas.append(Linha(ajuste: a, titulo: titulo, tomada: pt, bateria: pb))
        }
        onde.stringValue = estado.emUso.map { tf("O Mac está na %@ agora. Cada coluna vale quando o Mac está naquela fonte.", $0.nomeCurto) }
            ?? t("Cada coluna vale quando o Mac está naquela fonte.")
        atualizarRodape(mensagem: nil)
        janela.setContentSize(janela.contentView!.fittingSize)
    }

    private func tracinho() -> NSView {
        let l = NSTextField(labelWithString: "-")
        l.textColor = .tertiaryLabelColor
        l.alignment = .center
        return l
    }

    // MARK: Pendencias

    private func pendentes() -> [Escrita] {
        var lista: [Escrita] = []
        for l in linhas {
            let novoT = l.tomada?.selectedTag()
            let novoB = l.bateria?.selectedTag()
            let mudouT = novoT != nil && novoT != estado.tomada[l.ajuste.chave]
            let mudouB = novoB != nil && novoB != estado.bateria[l.ajuste.chave]
            if mudouT || mudouB {
                lista.append(Escrita(chave: l.ajuste.chave,
                                     tomada: mudouT ? novoT : nil,
                                     bateria: mudouB ? novoB : nil))
            }
        }
        return lista
    }

    private func atualizarRodape(mensagem: String?) {
        let n = pendentes().count
        for l in linhas { l.titulo.textColor = .labelColor }
        if let m = mensagem {
            status.stringValue = m
        } else if n == 0 {
            status.stringValue = t("Nenhuma alteração pendente.")
        } else {
            status.stringValue = n == 1 ? t("1 alteração pendente, uma autenticação para aplicar.")
                                        : tf("%d alterações pendentes, uma autenticação para aplicar todas.", n)
        }
        botaoAplicar.isEnabled = n > 0
        botaoReverter.isEnabled = n > 0
    }

    @objc private func mudou() { atualizarRodape(mensagem: nil) }

    @objc private func reverter() {
        for l in linhas {
            if let p = l.tomada,  let v = estado.tomada[l.ajuste.chave]  { p.selectItem(withTag: v) }
            if let p = l.bateria, let v = estado.bateria[l.ajuste.chave] { p.selectItem(withTag: v) }
        }
        atualizarRodape(mensagem: nil)
    }

    // MARK: Aplicar: um comando, uma autenticacao, releitura obrigatoria

    @objc private func aplicar() {
        let lista = pendentes()
        guard !lista.isEmpty else { return }

        // Avisos de risco: so quando a mudanca DESLIGA algo que esta ligado.
        for e in lista {
            guard let a = Catalogo.ajustes.first(where: { $0.chave == e.chave }), let aviso = a.aviso else { continue }
            let desliga = (e.tomada == 0 && estado.tomada[e.chave] == 1) || (e.bateria == 0 && estado.bateria[e.chave] == 1)
            if desliga, !Dialogos.confirmar(tf("Desligar “%@”?", a.titulo), aviso, botao: t("Desligar"), destrutivo: true).ok {
                return
            }
        }

        let comando = lista.map { $0.comando }.joined(separator: " && ")
        status.stringValue = t("Aguardando a autenticação…")
        botaoAplicar.isEnabled = false; botaoReverter.isEnabled = false
        janela.contentView?.display()

        let r = Privilegio.rodar(comando)
        switch r {
        case .cancelado:
            atualizarRodape(mensagem: t("Cancelado. Nada foi alterado."))
            botaoAplicar.isEnabled = true; botaoReverter.isEnabled = true
            return
        case .falha(let msg):
            atualizarRodape(mensagem: tf("Não foi possível aplicar: %@", msg))
            botaoAplicar.isEnabled = true; botaoReverter.isEnabled = true
            return
        case .ok:
            break
        }

        estado = Sistema.ler()
        let recusados = lista.filter { !estado.confere($0) }
        preencher()
        aoAplicar?()

        if recusados.isEmpty {
            atualizarRodape(mensagem: lista.count == 1 ? t("Aplicado e conferido no sistema.")
                                                        : tf("%d alterações aplicadas e conferidas no sistema.", lista.count))
        } else {
            let nomes = recusados.compactMap { r in Catalogo.ajustes.first { $0.chave == r.chave }?.titulo }
            for l in linhas where recusados.contains(where: { $0.chave == l.ajuste.chave }) {
                l.titulo.textColor = .systemRed
            }
            status.stringValue = tf("O macOS aceitou o comando mas recusou: %@. Os valores mostrados são os reais.", nomes.joined(separator: ", "))
        }
    }

    // MARK: Exibicao

    func mostrar() {
        estado = Sistema.ler()
        preencher()
        if !jaCentrou { janela.center(); jaCentrou = true }
        // App sem icone na Dock nao ganha o direito de ativar so com activate():
        // a janela abria ATRAS da janela da frente e parecia que nada tinha aberto.
        NSApp.activate(ignoringOtherApps: true)
        janela.orderFrontRegardless()
        janela.makeKeyAndOrderFront(nil)
    }
}
