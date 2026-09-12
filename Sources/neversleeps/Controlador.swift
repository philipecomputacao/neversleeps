// Controlador.swift — icone na barra, menu, escrita+conferencia e a orientacao
// de primeira vez. O teste da tampa esta em Controlador+Teste.swift.
import Cocoa
import ServiceManagement
import NeversleepsCore

final class Controlador: NSObject, NSApplicationDelegate, NSMenuDelegate {

    var item: NSStatusItem!
    let menu = NSMenu()
    var estado = Estado()
    var ocupado = false
    var timer: Timer?
    lazy var janelaAjuda = JanelaAjuda()
    lazy var janelaSobre = JanelaSobre()
    lazy var janelaAjustes: JanelaAjustes = {
        let j = JanelaAjustes()
        j.aoAplicar = { [weak self] in self?.recarregar() }
        return j
    }()

    // Estado do teste da tampa (logica em Controlador+Teste.swift).
    var testeInicio: Date?
    var testeUltimoBatimento = Date()
    var testeMaiorLacuna: TimeInterval = 0
    var testeTimer: Timer?
    var testeAtividade: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menu.delegate = self
        item.menu = menu
        recarregar()

        // O icone nao pode envelhecer: `sudo pmset` no Terminal precisa aparecer
        // aqui sem abrir o menu. Timer + despertar, lendo so a trava (1 processo).
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.conferirTrava()
        }
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(conferirTrava), name: NSWorkspace.didWakeNotification, object: nil)
        // Abrir a tampa dispara um destes dois (com a trava ligada a tela apaga e
        // acende; sem a trava o Mac repousa e desperta). Os dois avaliam o teste.
        for nome in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            nc.addObserver(self, selector: #selector(tampaAbriu), name: nome, object: nil)
        }
        // Despertou depois de um repouso por tampa fechada com a trava desligada?
        // E o erro classico: instalar e achar que fechar ja funciona. Avisa na hora.
        nc.addObserver(self, selector: #selector(despertouDoRepouso), name: NSWorkspace.didWakeNotification, object: nil)

        #if DEBUG
        // No diagnostico, nada de primeira vez: menu aberto e alerta modal
        // bloqueiam o run loop e o exit(0) nunca chega.
        if CommandLine.arguments.contains("--diagnostico-janelas")
            || CommandLine.arguments.contains("--capturar") { return }
        #endif

        // Primeira abertura: mostra onde o app mora, abrindo o proprio menu.
        if !Prefs.jaAbriu {
            Prefs.jaAbriu = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.item.button?.performClick(nil)
            }
        }
        // Boas-vindas: enquanto a trava estiver desligada e nunca tiver sido
        // testada, o app diz com todas as letras que instalar nao liga nada.
        if !Prefs.boasVindasVistas && estado.trava == false && Prefs.testeAprovadoEm == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.mostrarBoasVindas()
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        recarregar()
        montarMenu()
    }

    func recarregar() {
        estado = Sistema.ler()
        atualizarIcone()
    }

    @objc func conferirTrava() {
        guard !ocupado else { return }
        let nova = Sistema.lerTrava()
        if nova != estado.trava {
            estado.trava = nova
            atualizarIcone()
        }
    }

    // MARK: Identidade visual

    func atualizarIcone() {
        // Imagem template monocromatica, como todo app nativo na barra de menus.
        // Xicara vazia -> cheia e o padrao Apple para "engajado" sem usar cor.
        let nome: String, descricao: String
        if ocupado {
            nome = "hourglass"; descricao = t("Aguardando autenticação")
        } else if let trava = estado.trava {
            nome = trava ? "cup.and.saucer.fill" : "cup.and.saucer"
            descricao = trava ? t("Trava da tampa ligada") : t("Repouso normal")
        } else {
            nome = "exclamationmark.triangle"; descricao = t("Não foi possível ler o estado de energia")
        }
        let img = NSImage(systemSymbolName: nome, accessibilityDescription: descricao)
        img?.isTemplate = true
        item.button?.image = img
        item.button?.appearsDisabled = ocupado
        item.button?.toolTip = "neversleeps — " + descricao.lowercased()
    }

    func marcarOcupado(_ v: Bool) {
        ocupado = v
        atualizarIcone()
        item.button?.display()      // repinta AGORA, antes da chamada bloqueante
    }

    private func simbolo(_ nome: String) -> NSImage? {
        let img = NSImage(systemSymbolName: nome, accessibilityDescription: nil)
        img?.isTemplate = true
        return img
    }

    func itemMenu(_ titulo: String, _ sub: String = "", simbolo s: String? = nil,
                  acao: Selector? = nil) -> NSMenuItem {
        let i = NSMenuItem(title: titulo, action: acao, keyEquivalent: "")
        i.target = self
        if let s = s { i.image = simbolo(s) }
        if #available(macOS 14.4, *), !sub.isEmpty { i.subtitle = sub }
        return i
    }

    // MARK: Menu

    private func montarMenu() {
        menu.removeAllItems()

        // Leitura falhou: dizer "nao sei", nao fingir "tudo normal".
        guard estado.leituraOk else {
            let i = itemMenu(t("Não foi possível ler o estado de energia"),
                             t("O comando pmset não respondeu. Tente de novo."),
                             simbolo: "exclamationmark.triangle")
            i.isEnabled = false
            menu.addItem(i)
            menu.addItem(.separator())
            montarRodape()
            return
        }

        // A trava da tampa, primeira linha: e o motivo do app existir.
        let ligada = estado.trava == true
        let legenda: String
        if !ligada {
            legenda = t("Desligada: fechar a tampa põe o Mac em repouso")
        } else if testeInicio != nil {
            legenda = t("Ligada · teste em andamento: feche a tampa por 1 minuto")
        } else if let quando = Prefs.testeAprovadoEm {
            legenda = tf("Ligada · testada e aprovada %@", Dialogos.quando(quando))
        } else {
            legenda = t("Ligada · ainda não testada")
        }
        let tampa = itemMenu(Catalogo.tampa.titulo, legenda, simbolo: Catalogo.tampa.simbolo,
                             acao: #selector(alternarTampa))
        tampa.state = ligada ? .on : .off
        menu.addItem(tampa)

        // Ajustes finos moram numa JANELA (⌘,), como em todo app de barra de menus.
        menu.addItem(.separator())
        let ajustes = itemMenu(t("Ajustes de Energia…"),
                               estado.emUso.map { tf("O Mac está na %@ agora", $0.nomeCurto) } ?? "",
                               simbolo: "slider.horizontal.3", acao: #selector(abrirAjustes))
        ajustes.keyEquivalent = ","
        menu.addItem(ajustes)

        menu.addItem(.separator())
        montarRodape()
    }

    private func montarRodape() {
        // O teste e um item comum do rodape. A orientacao sobre ele acontece uma
        // vez so, nos dialogos de primeira vez.
        let teste: NSMenuItem
        if testeInicio != nil {
            teste = itemMenu(t("Teste em Andamento…"), t("Feche a tampa por 1 minuto e abra"),
                             simbolo: "hourglass", acao: #selector(testeEmAndamento))
        } else if estado.trava != true {
            teste = itemMenu(t("Testar a Tampa…"), t("Ligue a trava primeiro"), simbolo: "checkmark.circle")
            teste.isEnabled = false
        } else {
            let sub = Prefs.testeAprovadoEm.map {
                tf("Aprovado %@ — %d min %d s sem repousar", Dialogos.quando($0),
                   Prefs.testeAprovadoDuracao / 60, Prefs.testeAprovadoDuracao % 60) }
                ?? Prefs.testeUltimaFalha.map { tf("Reprovado: %@", $0) }
                ?? t("Feche o Mac 1 minuto; o app confere se ele repousou")
            teste = itemMenu(t("Testar a Tampa…"), sub,
                             simbolo: Prefs.testeUltimaFalha == nil ? "checkmark.circle" : "xmark.circle",
                             acao: #selector(iniciarTeste))
        }
        menu.addItem(teste)

        let login = itemMenu(t("Abrir no Início da Sessão"), acao: #selector(alternarLogin))
        switch SMAppService.mainApp.status {
        case .enabled: login.state = .on
        case .requiresApproval:
            login.state = .mixed
            if #available(macOS 14.4, *) { login.subtitle = t("Aguardando aprovação nos Ajustes do Sistema") }
        default: login.state = .off
        }
        menu.addItem(login)

        menu.addItem(itemMenu(t("Restaurar Padrões de Energia…"), simbolo: "arrow.counterclockwise",
                              acao: #selector(restaurarPadroes)))
        let ajuda = itemMenu(t("Ajuda do neversleeps"), simbolo: "questionmark.circle", acao: #selector(mostrarAjuda))
        ajuda.keyEquivalent = "?"
        ajuda.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(ajuda)
        menu.addItem(itemMenu(t("Sobre o neversleeps"), acao: #selector(mostrarSobre)))
        menu.addItem(.separator())

        let sair = itemMenu(t("Encerrar neversleeps"), acao: #selector(sair))
        sair.keyEquivalent = "q"
        menu.addItem(sair)
    }

    // MARK: Escrita + conferencia

    /// Escreve e RELE. Se o macOS aceitou e ignorou, o usuario fica sabendo.
    /// Roda num turno seguinte do run loop, para o menu fechar e o icone virar
    /// ampulheta ANTES da chamada bloqueante.
    func aplicar(_ e: Escrita, titulo: String) {
        executarPrivilegiado(e.comando, titulo: titulo) { [self] in
            if estado.confere(e), e.chave == Catalogo.chaveTrava, (e.tomada ?? 0) == 1,
               Prefs.testeAprovadoEm == nil, !Prefs.ofertaTesteVista {
                Prefs.ofertaTesteVista = true
                let (sim, _) = Dialogos.confirmar(
                    t("Trava ligada. Testar agora?"),
                    t("Ligada não é a mesma coisa que provada. O teste leva 1 minuto: feche a tampa, espere, abra. O app lê o log do sistema e diz se o Mac repousou.\n\nTambém dá para fazer depois, em “Testar a Tampa…” no menu."),
                    botao: t("Testar Agora"), destrutivo: false)
                if sim { iniciarTeste() }
                return
            }
            if !estado.confere(e) {
                let pedido: String
                if e.chave == Catalogo.chaveTrava {
                    pedido = ((e.tomada ?? e.bateria) == 1) ? t("ligada") : t("desligada")
                } else {
                    pedido = [e.tomada.map { "\(t("tomada")) \($0)" }, e.bateria.map { "\(t("bateria")) \($0)" }]
                        .compactMap { $0 }.joined(separator: ", ")
                }
                Dialogos.alerta(tf("Não foi possível aplicar “%@”.", titulo),
                                tf("O macOS aceitou o comando, mas manteve o valor anterior. Pedido: %@. Encontrado: %@. Isso acontece com ajustes que o sistema protege. O menu continua mostrando o valor real. (chave: %@)",
                                   pedido, estado.encontrado(e), e.chave))
            }
        }
    }

    func executarPrivilegiado(_ cmd: String, titulo: String, conferir: @escaping () -> Void) {
        marcarOcupado(true)
        DispatchQueue.main.async { [self] in
            let r = Privilegio.rodar(cmd)
            marcarOcupado(false)
            switch r {
            case .cancelado:
                return                                   // uso normal: ficar calado
            case .falha(let msg):
                recarregar()
                Dialogos.alerta(tf("Não foi possível alterar “%@”.", titulo), msg)
            case .ok:
                recarregar()
                conferir()
            }
        }
    }

    // MARK: Acoes

    @objc func alternarTampa() {
        guard let trava = estado.trava else { return }
        let novo = trava ? 0 : 1
        if novo == 1, !Prefs.avisoTampaVisto, let aviso = Catalogo.tampa.aviso {
            // Aviso educativo: uma vez, com "nao mostrar de novo".
            let (ok, suprimir) = Dialogos.confirmar(t("Ligar a trava da tampa?"), aviso,
                                                    botao: t("Ligar"), destrutivo: false, comSupressao: true)
            if suprimir { Prefs.avisoTampaVisto = true }
            if !ok { return }
        }
        aplicar(Escrita(chave: Catalogo.chaveTrava, tomada: novo, bateria: novo), titulo: Catalogo.tampa.titulo)
    }

    @objc func abrirAjustes() { janelaAjustes.mostrar() }
    @objc func mostrarAjuda() { janelaAjuda.mostrar() }
    @objc func mostrarSobre() { janelaSobre.mostrar() }
    @objc func sair() { NSApp.terminate(nil) }

    @objc func restaurarPadroes() {
        let (ok, _) = Dialogos.confirmar(
            t("Restaurar os padrões de energia do macOS?"),
            t("Desfaz todas as alterações feitas aqui e pelo Terminal, inclusive a trava da tampa. Nada além da energia é afetado."),
            botao: t("Restaurar"), destrutivo: true)
        guard ok else { return }
        executarPrivilegiado("/usr/bin/pmset -a disablesleep 0 && /usr/bin/pmset restoredefaults",
                             titulo: t("Restaurar Padrões de Energia")) { [self] in
            if estado.trava != false {
                Dialogos.alerta(t("Não foi possível desligar a trava da tampa."),
                                t("O macOS aceitou o comando, mas a trava continua ligada. O menu continua mostrando o valor real."))
            }
        }
    }

    @objc func alternarLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled:
                try SMAppService.mainApp.unregister()
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            default:
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } catch {
            Dialogos.alerta(t("Não foi possível alterar a abertura no início da sessão."),
                            error.localizedDescription + "\n\n" + t("Isso costuma acontecer quando o app não está instalado como bundle em /Applications."))
        }
    }

    // MARK: Orientacao no momento do erro

    func mostrarBoasVindas() {
        Prefs.boasVindasVistas = true
        let (ligar, _) = Dialogos.confirmar(
            t("O Mac ainda repousa ao fechar a tampa."),
            t("Instalar o neversleeps não muda nada sozinho. Para trabalhar fechado, é preciso LIGAR a trava — um clique e uma autenticação. A xícara na barra de menus fica cheia.\n\nLigada, o Mac nunca repousa sozinho, mesmo fechado: não o guarde na mochila com ela ligada se estiver fazendo algo pesado.\n\nPara usar na rua, deixe o iPhone entrar sozinho como internet: Ajustes do Sistema → Wi-Fi → Acesso Pessoal → Automaticamente. O app não controla isso; a Ajuda explica."),
            botao: t("Ligar a Trava Agora"), destrutivo: false)
        guard ligar else { return }
        Prefs.avisoTampaVisto = true       // o aviso da mochila acabou de ser dado aqui
        aplicar(Escrita(chave: Catalogo.chaveTrava, tomada: 1, bateria: 1), titulo: Catalogo.tampa.titulo)
    }

    @objc func despertouDoRepouso() {
        guard testeInicio == nil, !Prefs.avisoRepousoSilenciado else { return }
        // 3 s para o log assentar e para a trava ser relida.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.recarregar()
            guard self.estado.trava == false else { return }
            let recentes = Sistema.repousosDesde(Date().addingTimeInterval(-15 * 60))
            guard let porTampa = recentes.last(where: { $0.motivo.contains("Clamshell") }) else { return }
            let (ligar, silenciar) = Dialogos.confirmar(
                t("O Mac repousou ao fechar a tampa."),
                tf("Registro do sistema: %@.\n\nA trava estava DESLIGADA, então nada do que estava rodando continuou. Se você fechou o Mac esperando que ele trabalhasse, esse é o motivo.\n\nLigar a trava agora? (um clique e uma autenticação)", porTampa.descricao),
                botao: t("Ligar a Trava Agora"), destrutivo: false, comSupressao: true)
            if silenciar { Prefs.avisoRepousoSilenciado = true }
            guard ligar else { return }
            Prefs.avisoTampaVisto = true
            self.aplicar(Escrita(chave: Catalogo.chaveTrava, tomada: 1, bateria: 1), titulo: Catalogo.tampa.titulo)
        }
    }

    #if DEBUG
    /// `--capturar <pasta>`: renderiza as janelas do app e o menu aberto em PNG,
    /// sem Gravacao de Tela — o macOS deixa capturar janelas do PROPRIO processo.
    /// E como nascem os screenshots do README: pixels reais, nao mockup.
    func capturarJanelas(em pasta: String) {
        let dir = URL(fileURLWithPath: pasta)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        func salvar(_ id: CGWindowID, _ nome: String) {
            guard let img = CGWindowListCreateImage(.null, .optionIncludingWindow, id,
                                                    [.bestResolution, .boundsIgnoreFraming]) else {
                print("FALHA ao capturar \(nome)"); return
            }
            let rep = NSBitmapImageRep(cgImage: img)
            guard let png = rep.representation(using: .png, properties: [:]) else { return }
            let destino = dir.appendingPathComponent(nome + ".png")
            try? png.write(to: destino)
            print("capturado: \(destino.path) (\(img.width)x\(img.height))")
        }

        // 1. Janelas: mostra, espera pintar, captura pelo windowNumber, esconde.
        // A janela do proprio icone da barra ("Item-0") tem windowNumber 2^32:
        // cabe em Int, nao em CGWindowID. So janelas de verdade entram.
        func capturavel(_ w: NSWindow) -> Bool {
            w.isVisible && !w.title.isEmpty && !w.title.hasPrefix("Item-")
                && w.windowNumber > 0 && w.windowNumber <= Int(UInt32.max)
        }
        janelaAjustes.mostrar()
        janelaSobre.mostrar()
        janelaAjuda.mostrar()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
            for w in NSApp.windows.filter(capturavel) {
                let nome = w.title.lowercased()
                    .replacingOccurrences(of: " ", with: "-")
                    .folding(options: .diacriticInsensitive, locale: .current)
                salvar(CGWindowID(w.windowNumber), nome)
                w.orderOut(nil)
            }
            // 2. Menu: o rastreamento do menu roda um run loop aninhado (a fila
            //    principal para; asyncAfter NAO dispara). Um Timer em modo .common
            //    ainda dispara. Fotografa a cada 0,25 s enquanto o menu existir e
            //    fica a ultima foto — a primeira sai no meio da animacao de abertura.
            let conhecidas = Set(NSApp.windows.filter(capturavel).map { CGWindowID($0.windowNumber) })
            var ticks = 0
            var fotos = 0
            let t = Timer(timeInterval: 0.25, repeats: true) { [self] timer in
                ticks += 1
                let lista = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
                for w in lista {
                    guard let pid = w[kCGWindowOwnerPID as String] as? Int32, pid == getpid(),
                          let id = w[kCGWindowNumber as String] as? UInt32, !conhecidas.contains(id),
                          let bounds = w[kCGWindowBounds as String] as? [String: CGFloat],
                          (bounds["Height"] ?? 0) > 60 else { continue }
                    salvar(id, "menu"); fotos += 1
                }
                if ticks >= 8 {
                    timer.invalidate()
                    print(fotos > 0 ? "menu: \(fotos) fotos, ficou a ultima" : "FALHA: menu nao apareceu")
                    menu.cancelTracking()
                    let fim = Timer(timeInterval: 0.3, repeats: false) { _ in exit(0) }
                    RunLoop.main.add(fim, forMode: .common)
                }
            }
            RunLoop.main.add(t, forMode: .common)
            item.button?.performClick(nil)
        }
    }

    func diagnosticoJanelas() {
        janelaAjustes.mostrar()
        janelaAjuda.mostrar()
        janelaSobre.mostrar()
        for w in NSApp.windows {
            print("janela: \(w.title.isEmpty ? "(sem titulo)" : w.title)  frame=\(NSStringFromRect(w.frame))  visivel=\(w.isVisible)")
        }
    }
    #endif
}
