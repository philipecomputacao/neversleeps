// JanelaSobre.swift, a janela "Sobre": versao, licenca, links e a promessa
// que vale ouro num app de energia: sem rede, sem telemetria.
import Cocoa
import NeversleepsCore

final class JanelaSobre: NSObject {

    static let repositorio = URL(string: "https://github.com/philipecomputacao/neversleeps")!
    static let licenca = URL(string: "https://github.com/philipecomputacao/neversleeps/blob/main/LICENSE")!
    static let autor = URL(string: "https://lpdigital.me")!

    private let janela: NSWindow
    private var jaCentrou = false

    override init() {
        janela = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 300),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        janela.title = t("Sobre o neversleeps")
        janela.isReleasedWhenClosed = false
        montar()
    }

    private func montar() {
        let info = Bundle.main.infoDictionary ?? [:]
        let versao = info["CFBundleShortVersionString"] as? String ?? "-"

        let icone = NSImageView(image: NSApp.applicationIconImage)
        icone.imageScaling = .scaleProportionallyUpOrDown
        icone.widthAnchor.constraint(equalToConstant: 96).isActive = true
        icone.heightAnchor.constraint(equalToConstant: 96).isActive = true

        let nome = NSTextField(labelWithString: "neversleeps")
        nome.font = .systemFont(ofSize: 20, weight: .bold)
        nome.alignment = .center

        let ver = NSTextField(labelWithString: tf("Versão %@", versao))
        ver.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        ver.textColor = .secondaryLabelColor
        ver.alignment = .center

        let promessa = NSTextField(wrappingLabelWithString:
            t("Mantém o Mac trabalhando com a tampa fechada.\n\nSem rede. Sem telemetria. Nada sai da sua máquina."))
        promessa.alignment = .center
        promessa.preferredMaxLayoutWidth = 300

        let botoes = NSStackView(views: [
            botao(t("Código-fonte"), #selector(abrirRepositorio)),
            botao(t("Licença MIT"), #selector(abrirLicenca)),
        ])
        botoes.orientation = .horizontal
        botoes.spacing = 8

        let rodape = NSTextField(labelWithString: "© 2026 LP Digital · lpdigital.me")
        rodape.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        rodape.textColor = .tertiaryLabelColor
        rodape.alignment = .center

        let pilha = NSStackView(views: [icone, nome, ver, promessa, botoes, rodape])
        pilha.orientation = .vertical
        pilha.alignment = .centerX
        pilha.spacing = 8
        pilha.setCustomSpacing(2, after: nome)
        pilha.setCustomSpacing(16, after: ver)
        pilha.setCustomSpacing(16, after: promessa)
        pilha.setCustomSpacing(16, after: botoes)
        pilha.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 20, right: 24)
        pilha.translatesAutoresizingMaskIntoConstraints = false

        let conteudo = NSView()
        conteudo.addSubview(pilha)
        NSLayoutConstraint.activate([
            pilha.topAnchor.constraint(equalTo: conteudo.topAnchor),
            pilha.bottomAnchor.constraint(equalTo: conteudo.bottomAnchor),
            pilha.leadingAnchor.constraint(equalTo: conteudo.leadingAnchor),
            pilha.trailingAnchor.constraint(equalTo: conteudo.trailingAnchor),
            pilha.widthAnchor.constraint(equalToConstant: 360),
        ])
        janela.contentView = conteudo
        janela.setContentSize(conteudo.fittingSize)
    }

    private func botao(_ titulo: String, _ acao: Selector) -> NSButton {
        let b = NSButton(title: titulo, target: self, action: acao)
        b.bezelStyle = .rounded
        return b
    }

    @objc private func abrirRepositorio() { NSWorkspace.shared.open(Self.repositorio) }
    @objc private func abrirLicenca() { NSWorkspace.shared.open(Self.licenca) }

    func mostrar() {
        if !jaCentrou { janela.center(); jaCentrou = true }
        NSApp.activate(ignoringOtherApps: true)
        janela.orderFrontRegardless()
        janela.makeKeyAndOrderFront(nil)
    }
}
