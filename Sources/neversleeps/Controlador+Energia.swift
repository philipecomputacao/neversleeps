// Controlador+Energia.swift, o modulo Falta de Energia no app: observa quando
// o Mac sai da tomada, reconhece um reinicio inesperado, conta o que aconteceu
// e reabre as tarefas cadastradas no Terminal.
//
// Tres testemunhas, nenhuma exige senha:
//   1. kern.boottime muda a cada partida do Mac, e so a cada partida;
//   2. applicationWillTerminate / willPowerOff: desligar ou reiniciar pelo menu
//      encerra os apps; queda de energia, panico e botao segurado nao;
//   3. o registro do periodo na bateria (IOKit avisa cada mudanca de fonte e
//      de carga), mais o batimento de 30 s.
// O que o app NAO faz: soltar a trava sozinho quando a bateria esta no fim.
// Isso exigiria root sem dialogo (regra 1) e, medido no kernel, nem o repouso
// de emergencia passa com a trava ligada. Ver Energia.swift.
import Cocoa
import IOKit.ps
import Network
import NeversleepsCore

extension Controlador {

    /// Chamado uma vez, na partida do app. A ordem importa: avaliar a partida
    /// ANTES de registrar a fonte atual, senao o periodo na bateria da partida
    /// anterior e fechado com a hora de agora e a prova some.
    func iniciarEnergia() {
        avaliarPartida()
        fonteMudou()

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        if let fonte = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx = ctx else { return }
            Unmanaged<Controlador>.fromOpaque(ctx).takeUnretainedValue().fonteMudou()
        }, ctx)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), fonte, .defaultMode)
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(fimVisto), name: NSWorkspace.willPowerOffNotification, object: nil)
    }

    /// O app viu o proprio fim nesta partida: o proximo boot nao e surpresa.
    @objc func fimVisto() {
        Prefs.encerradoNoBoot = Sistema.partidaAtual()
    }

    /// Batimento, chamado pelo timer de 30 s.
    func sinal() {
        Prefs.ultimoSinal = Date()
    }

    /// IOKit avisa mudanca de fonte E de carga. Abre, atualiza ou fecha o periodo.
    func fonteMudou() {
        let (fonte, carga) = Sistema.lerBateria()
        let agora = Date()
        var p = Prefs.periodoNaBateria
        switch fonte {
        case .bateria?:
            if var aberto = p, aberto.fim == nil {
                aberto.ultimaLeitura = agora; aberto.ultimaBateria = carga
                p = aberto
            } else {
                p = PeriodoNaBateria(inicio: agora, bateriaInicio: carga)
            }
        case .tomada?:
            guard var aberto = p, aberto.fim == nil else { return }
            aberto.fim = agora
            p = aberto
        case nil:
            return
        }
        Prefs.periodoNaBateria = p
    }

    // MARK: Reinicio inesperado

    func avaliarPartida() {
        guard let atual = Sistema.partidaAtual() else { return }
        let veredito = Reinicio.avaliar(bootAtual: atual, bootConhecido: Prefs.partidaConhecida,
                                        encerradoNoBoot: Prefs.encerradoNoBoot)
        let periodo = Prefs.periodoNaBateria
        let ultimoSinal = Prefs.ultimoSinal
        Prefs.partidaConhecida = atual

        // Partida nova com periodo aberto: o Mac desligou na bateria. O fim do
        // periodo e a ultima leitura, nao agora.
        if veredito != .mesmaPartida, var p = periodo, p.fim == nil {
            p.fim = p.ultimaLeitura
            Prefs.periodoNaBateria = p
        }
        guard veredito == .inesperado else { return }

        let religou = Date(timeIntervalSince1970: atual)
        let texto = relato(causa: Relato.causa(periodo), periodo: periodo,
                           ultimoSinal: ultimoSinal, religou: religou)
        Prefs.ultimoRelato = texto
        Prefs.ultimoRelatoEm = religou

        let tarefas = Prefs.retomarLigado ? Prefs.tarefas.filter { $0.valida } : []
        // A rede demora a subir depois do login, e o Claude precisa dela.
        aguardarRede { [weak self] in
            guard let self = self else { return }
            let falharam = tarefas.isEmpty ? [] : self.abrirTarefas(tarefas)
            self.mostrarRelato(texto, tarefas: tarefas.count, falharam: falharam)
        }
    }

    func relato(causa: CausaProvavel, periodo: PeriodoNaBateria?, ultimoSinal: Date?, religou: Date) -> String {
        var linhas: [String] = []
        switch causa {
        case .bateriaAcabou:
            let p = periodo!
            linhas.append(tf("O Mac estava na bateria desde %@ (%@). O último registro foi %@, com %@: a bateria acabou.",
                             Dialogos.quando(p.inicio), porcento(p.bateriaInicio),
                             Dialogos.quando(p.ultimaLeitura), porcento(p.ultimaBateria)))
        case .estavaNaBateria:
            let p = periodo!
            linhas.append(tf("O Mac estava na bateria desde %@. O último registro foi %@, com %@. A carga não explica o desligamento: pode ter sido um travamento ou o botão de ligar segurado.",
                             Dialogos.quando(p.inicio), Dialogos.quando(p.ultimaLeitura), porcento(p.ultimaBateria)))
        case .desconhecida:
            let quando = ultimoSinal.map { Dialogos.quando($0) } ?? t("sem registro")
            linhas.append(tf("O Mac estava na tomada, então não foi a bateria. Último sinal do app: %@. Causas comuns: travamento, erro do sistema ou o botão de ligar segurado.", quando))
        }
        linhas.append(tf("Religou %@.", Dialogos.quando(religou)))
        return linhas.joined(separator: " ")
    }

    private func porcento(_ n: Int?) -> String { n.map { "\($0)%" } ?? t("carga desconhecida") }

    func mostrarRelato(_ texto: String, tarefas: Int, falharam: [String]) {
        recarregar()
        var corpo = texto + "\n\n"
        if tarefas == 0 {
            corpo += Prefs.tarefas.isEmpty
                ? t("Nenhuma tarefa cadastrada para retomar. Em “Falta de Energia…” você escolhe o que o app reabre no Terminal depois de um reinício.")
                : t("A retomada está desligada em “Falta de Energia…”.")
        } else if falharam.isEmpty {
            corpo += tf("Tarefas reabertas no Terminal: %d.", tarefas)
        } else {
            corpo += tf("Reabertas %d de %d tarefas. Não abriram: %@.", tarefas - falharam.count, tarefas, falharam.joined(separator: ", "))
        }
        if estado.trava == false {
            corpo += "\n\n" + t("A trava da tampa está DESLIGADA agora: fechar o Mac o põe em repouso.")
        }

        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = t("O Mac reiniciou sem ninguém mandar.")
        a.informativeText = corpo
        a.addButton(withTitle: t("OK"))
        a.addButton(withTitle: t("Falta de Energia…"))
        if a.runModal() == .alertSecondButtonReturn { abrirEnergia() }
    }

    // MARK: Retomada

    /// Escreve um .command por tarefa e o abre no Terminal. Abrir um .command e
    /// o caminho sem Automacao: nao pede permissao para controlar o Terminal.
    /// Devolve as pastas que NAO abriram.
    @discardableResult
    func abrirTarefas(_ tarefas: [Tarefa]) -> [String] {
        let fm = FileManager.default
        guard let suporte = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return tarefas.map { $0.pasta }
        }
        let dir = suporte.appendingPathComponent("neversleeps/retomar", isDirectory: true)
        try? fm.removeItem(at: dir)       // sobra de uma retomada anterior
        do { try fm.createDirectory(at: dir, withIntermediateDirectories: true) }
        catch { return tarefas.map { $0.pasta } }

        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        var falharam: [String] = []
        for (i, tarefa) in tarefas.enumerated() {
            let arquivo = dir.appendingPathComponent("tarefa-\(i + 1).command")
            do {
                try tarefa.script(casa: NSHomeDirectory()).write(to: arquivo, atomically: true, encoding: .utf8)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: arquivo.path)
            } catch {
                falharam.append(tarefa.pasta); continue
            }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open([arquivo], withApplicationAt: terminal, configuration: config) { _, erro in
                if erro != nil { NSLog("neversleeps: nao abriu %@: %@", arquivo.path, erro!.localizedDescription) }
            }
        }
        return falharam
    }

    /// Espera a rede ficar disponivel, no maximo 60 s, e segue de qualquer jeito.
    /// NWPathMonitor so observa as interfaces: nao envia nada pela rede.
    func aguardarRede(_ depois: @escaping () -> Void) {
        let monitor = NWPathMonitor()
        var feito = false
        let seguir = {
            guard !feito else { return }
            feito = true
            monitor.cancel()
            depois()
        }
        monitor.pathUpdateHandler = { caminho in
            if caminho.status == .satisfied {
                // Um respiro para o DNS e o proxy do sistema assentarem.
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { seguir() }
            }
        }
        monitor.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { seguir() }
    }
}
