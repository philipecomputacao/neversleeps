// Historico.swift, o ponto unico por onde o app anota um acontecimento.
// Grava no diario (NeversleepsCore/Registro.swift) e avisa a janela Historico,
// que se redesenha se estiver aberta. Tudo local: nada sai do Mac (regra 3).
import Cocoa
import NeversleepsCore

enum Historico {
    static let mudou = Notification.Name("me.lpdigital.neversleeps.historicoMudou")

    static let diario: Diario = {
        #if DEBUG
        // Build de debug: `NEVERSLEEPS_HISTORICO=<arquivo>` usa outro diario, para
        // demonstracao e capturas nao sujarem o historico real.
        if let caminho = ProcessInfo.processInfo.environment["NEVERSLEEPS_HISTORICO"] {
            return Diario(url: URL(fileURLWithPath: caminho))
        }
        #endif
        let suporte = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return Diario(url: suporte.appendingPathComponent("neversleeps/historico.jsonl"))
    }()

    static func anotar(_ e: Evento) {
        diario.acrescentar(e)
        let avisar = { NotificationCenter.default.post(name: mudou, object: nil) }
        Thread.isMainThread ? avisar() : DispatchQueue.main.async(execute: avisar)
    }

    static func anotar(_ tipo: TipoEvento, _ ajuste: (inout Evento) -> Void = { _ in }) {
        var e = Evento(tipo)
        ajuste(&e)
        anotar(e)
    }

    #if DEBUG
    /// `--historico-demo`: um dia realista, relativo a agora. So roda com
    /// NEVERSLEEPS_HISTORICO definido, para nunca escrever no diario real.
    static func semearDemonstracao() {
        guard ProcessInfo.processInfo.environment["NEVERSLEEPS_HISTORICO"] != nil else {
            print("--historico-demo exige NEVERSLEEPS_HISTORICO=<arquivo>"); exit(1)
        }
        diario.apagar()
        let agora = Date()
        func h(_ horas: Double) -> Date { agora.addingTimeInterval(-horas * 3600) }
        func e(_ tipo: TipoEvento, _ horas: Double, _ ajuste: (inout Evento) -> Void = { _ in }) {
            var ev = Evento(tipo, quando: h(horas)); ajuste(&ev); diario.acrescentar(ev)
        }
        e(.appAbriu, 30) { $0.fonte = .tomada }
        e(.repousou, 23.5) { $0.porTampa = true; $0.trava = false }
        e(.despertou, 21.3) { $0.duracao = Int(2.2 * 3600) }
        e(.travaLigada, 21.2) { $0.origem = .menu }
        e(.testeAprovado, 21.1) { $0.duracao = 72 }
        e(.saiuDaTomada, 9) { $0.carga = 100; $0.trava = true }
        let hora = { (d: Date) in DateFormatter.localizedString(from: d, dateStyle: .none, timeStyle: .short) }
        e(.reinicioInesperado, 3.1) {
            $0.inicio = h(5.6); $0.fonte = .tomada
            $0.detalhe = tf("O Mac estava na bateria desde %@ (%@). O último registro foi %@, com %@: a bateria acabou.",
                            hora(h(9)), "100%", hora(h(5.6)), "2%") + " " + tf("Religou %@.", hora(h(3.1)))
            $0.abertas = 2; $0.total = 2
        }
        e(.ajustesAplicados, 1.5) { $0.chaves = ["displaysleep", "powernap"] }
    }
    #endif

    /// Legenda do item do menu: o ultimo acontecimento e a hora.
    static func ultimo() -> String {
        guard let e = diario.ler().last else { return t("Nada registrado ainda") }
        // Hoje basta a hora; outro dia leva a data relativa ("ontem 13:02").
        let quando = Calendar.current.isDateInToday(e.quando)
            ? DateFormatter.localizedString(from: e.quando, dateStyle: .none, timeStyle: .short)
            : Dialogos.quando(e.quando).lowercased()
        return e.titulo + " · " + quando
    }

    // MARK: Identidade visual de cada tipo (simbolo SF + cor do sistema)

    static func simbolo(_ e: Evento) -> String {
        switch e.tipo {
        case .saiuDaTomada:       return "battery.50percent"
        case .voltouATomada:      return "powerplug"
        case .repousou:           return "moon.zzz"
        case .despertou:          return "sunrise"
        case .travaLigada:        return "cup.and.saucer.fill"
        case .travaDesligada:     return "cup.and.saucer"
        case .testeAprovado:      return "checkmark.circle"
        case .testeReprovado:     return "xmark.circle"
        case .desligou:           return "power"
        case .macLigou:           return "power.circle"
        case .reinicioInesperado: return "bolt.slash"
        case .retomada:           return "terminal"
        case .ajustesAplicados:   return "slider.horizontal.3"
        case .partidaAlterada:    return "bolt.horizontal.circle"
        case .padroesRestaurados: return "arrow.counterclockwise"
        case .appEncerrado:       return "xmark.square"
        case .appAbriu:           return "play.circle"
        }
    }

    static func cor(_ e: Evento) -> NSColor {
        switch e.tipo {
        case .saiuDaTomada:                          return .systemOrange
        case .repousou:
            // O erro classico: fechou esperando que o Mac trabalhasse.
            return (e.porTampa == true && e.trava == false) ? .systemRed : .systemPurple
        case .despertou:                             return .systemPurple
        case .travaLigada, .travaDesligada, .retomada: return .systemTeal
        case .testeAprovado:                         return .systemGreen
        case .testeReprovado, .reinicioInesperado:   return .systemRed
        case .ajustesAplicados, .partidaAlterada, .padroesRestaurados: return .systemBlue
        case .voltouATomada, .desligou, .macLigou, .appEncerrado, .appAbriu: return .systemGray
        }
    }

    static func cor(_ f: Faixa) -> NSColor {
        switch f {
        case .tomada:       return NSColor.systemGray.withAlphaComponent(0.35)
        case .bateria:      return .systemOrange
        case .repouso:      return NSColor.systemPurple.withAlphaComponent(0.55)
        case .desligado:    return NSColor.systemGray.withAlphaComponent(0.12)
        case .desconhecido: return NSColor.separatorColor.withAlphaComponent(0.25)
        }
    }

    static func nome(_ f: Faixa) -> String {
        switch f {
        case .tomada:       return t("Tomada")
        case .bateria:      return t("Bateria")
        case .repouso:      return t("Repouso")
        case .desligado:    return t("Desligado")
        case .desconhecido: return t("Sem registro")
        }
    }
}
