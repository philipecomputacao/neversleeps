// Registro.swift, o Historico: o diario do que o app viu acontecer, a frase de
// cada acontecimento e a fita das ultimas 24 horas. Sem AppKit, testavel.
//
// POR QUE UM DIARIO PROPRIO (medido em 29/09/2026, M1, macOS 26.2)
// `pmset -g log` guarda 7 dias em 377 mil linhas (99% assertions e despertares
// de manutencao) e custa 14 s de CPU por leitura; `log show` custa 13 s. Nenhum
// serve para abrir uma janela. O app anota cada acontecimento no instante em
// que ve, e o Historico le um arquivo pequeno. O diario e HISTORIA, nao estado:
// menu e icone continuam perguntando ao sistema.
import Foundation

// MARK: - Evento

public enum TipoEvento: String, Codable, CaseIterable {
    case saiuDaTomada, voltouATomada
    case repousou, despertou
    case travaLigada, travaDesligada
    case testeAprovado, testeReprovado
    case desligou, macLigou, reinicioInesperado, retomada
    case ajustesAplicados, partidaAlterada, padroesRestaurados
    case appEncerrado, appAbriu
}

public enum CategoriaEvento: CaseIterable {
    case energia, trava, reinicios
}

public enum Origem: String, Codable {
    case menu        // pelo proprio app
    case fora        // pelo Terminal ou outro programa: o timer de 30 s viu
    case padroes     // Restaurar Padroes de Energia
}

public struct Evento: Codable, Equatable {
    public var quando: Date
    public var tipo: TipoEvento
    public var carga: Int? = nil
    public var cargaInicial: Int? = nil
    public var porTampa: Bool? = nil
    public var trava: Bool? = nil
    public var duracao: Int? = nil          // segundos
    public var origem: Origem? = nil
    public var fonte: Fonte? = nil          // fonte na partida (macLigou, reinicioInesperado)
    public var inicio: Date? = nil          // reinicioInesperado: ultimo sinal antes de apagar
    public var detalhe: String? = nil       // narrativa pronta (relato, motivo do teste)
    // Dados, nao frases: a frase e montada na hora de mostrar, no idioma de
    // agora. Guardar texto traduzido congelava o idioma do dia da anotacao.
    public var chaves: [String]? = nil      // ajustesAplicados: chaves do catalogo
    public var aoCarregador: Bool? = nil    // partidaAlterada
    public var aoAbrirTampa: Bool? = nil    // partidaAlterada
    public var abertas: Int? = nil          // retomada, reinicioInesperado
    public var total: Int? = nil

    public init(_ tipo: TipoEvento, quando: Date = Date()) {
        self.tipo = tipo; self.quando = quando
    }

    public var categoria: CategoriaEvento {
        switch tipo {
        case .saiuDaTomada, .voltouATomada, .repousou, .despertou,
             .ajustesAplicados, .partidaAlterada, .padroesRestaurados: return .energia
        case .travaLigada, .travaDesligada, .testeAprovado, .testeReprovado: return .trava
        case .desligou, .macLigou, .reinicioInesperado, .retomada,
             .appEncerrado, .appAbriu: return .reinicios
        }
    }

    // MARK: Frases

    public var titulo: String {
        switch tipo {
        case .saiuDaTomada:       return t("Saiu da tomada")
        case .voltouATomada:      return t("Voltou para a tomada")
        case .repousou:           return porTampa == true ? t("Repousou ao fechar a tampa") : t("Repousou")
        case .despertou:          return t("Despertou")
        case .travaLigada:        return t("Trava ligada")
        case .travaDesligada:     return t("Trava desligada")
        case .testeAprovado:      return t("Teste da tampa aprovado")
        case .testeReprovado:     return t("Teste da tampa reprovado")
        case .desligou:           return t("Mac desligado ou reiniciado")
        case .macLigou:           return t("Mac ligou")
        case .reinicioInesperado: return t("O Mac reiniciou sem ninguém mandar")
        case .retomada:           return t("Tarefas reabertas no Terminal")
        case .ajustesAplicados:   return t("Ajustes de energia aplicados")
        case .partidaAlterada:    return t("Ligar sozinho alterado")
        case .padroesRestaurados: return t("Padrões de energia restaurados")
        case .appEncerrado:       return t("neversleeps encerrado")
        case .appAbriu:           return t("neversleeps aberto")
        }
    }

    public var descricao: String {
        if let d = detalhe, !d.isEmpty { return d }
        switch tipo {
        case .saiuDaTomada:
            var partes = [carga.map { tf("%d%% de carga", $0) } ?? t("carga desconhecida")]
            if trava == true { partes.append(t("a trava estava ligada")) }
            return partes.joined(separator: " · ")
        case .voltouATomada:
            var partes: [String] = []
            if let d = duracao { partes.append(tf("%@ na bateria", Evento.duracao(d))) }
            if let a = cargaInicial, let b = carga { partes.append("\(a)% → \(b)%") }
            else if let b = carga { partes.append(tf("%d%% de carga", b)) }
            return partes.joined(separator: " · ")
        case .repousou:
            if porTampa == true && trava == false { return t("A trava estava desligada") }
            return porTampa == true ? t("Tampa fechada") : t("Por inatividade ou pelo menu Apple")
        case .despertou:
            return duracao.map { tf("Dormiu %@", Evento.duracao($0)) } ?? ""
        case .travaLigada, .travaDesligada:
            switch origem {
            case .menu?:    return t("Pelo menu")
            case .fora?:    return t("Por fora do app: Terminal ou outro programa")
            case .padroes?: return t("Ao restaurar os padrões")
            case nil:       return ""
            }
        case .testeAprovado:
            return duracao.map { tf("%@ fechado, sem repouso", Evento.duracao($0)) } ?? ""
        case .desligou:
            return t("Pelo menu Apple: o app viu e encerrou junto")
        case .macLigou:
            return t("Depois de um desligamento normal")
        case .appEncerrado:
            return t("O histórico fica parado até o app abrir de novo")
        case .ajustesAplicados:
            let nomes = (chaves ?? []).compactMap { c in Catalogo.ajustes.first { $0.chave == c }?.titulo }
            return nomes.joined(separator: ", ")
        case .partidaAlterada:
            guard let c = aoCarregador, let l = aoAbrirTampa else { return "" }
            let sn = { (b: Bool) in b ? t("sim") : t("não") }
            return tf("Ao conectar o carregador: %@ · ao abrir a tampa: %@", sn(c), sn(l))
        case .retomada:
            return origem == .menu ? t("Retomar Agora, pela janela Falta de Energia") : ""
        default:
            return ""
        }
    }

    /// Destaque sob o detalhe: quantas tarefas a retomada reabriu.
    public var selo: String? {
        guard let a = abertas, let n = total, n > 0 else { return nil }
        if a == n { return a == 1 ? t("1 tarefa reaberta no Terminal") : tf("%d tarefas reabertas no Terminal", a) }
        return tf("%d de %d abertas", a, n)
    }

    /// "2 h 14 min", "12 min", "45 s". Arredonda para o que importa.
    public static func duracao(_ segundos: Int) -> String {
        let s = max(0, segundos)
        if s < 60 { return tf("%d s", s) }
        let min = s / 60
        // Abaixo de 5 min os segundos contam (o teste da tampa dura ~1 min).
        if min < 5 && s % 60 != 0 { return tf("%d min %d s", min, s % 60) }
        if min < 60 { return tf("%d min", min) }
        let h = min / 60, resto = min % 60
        if h < 48 { return resto == 0 ? tf("%d h", h) : tf("%d h %d min", h, resto) }
        return tf("%d dias", h / 24)
    }

    /// Uma linha de texto, para o "Copiar" do Historico.
    public func linhaTexto(_ formato: DateFormatter) -> String {
        let d = descricao
        return formato.string(from: quando) + "  " + titulo + (d.isEmpty ? "" : ". " + d) + (selo.map { " [\($0)]" } ?? "")
    }
}

// MARK: - Diario (JSON Lines em disco)

/// Um evento por linha. Acrescentar e O(1); a poda reescreve o arquivo e roda
/// na partida do app. Linha que nao decodifica (versao futura, arquivo
/// cortado) e ignorada, nao derruba a leitura.
public final class Diario {
    public static let diasGuardados = 30
    public static let maximo = 1000

    public let url: URL
    private let fila = DispatchQueue(label: "neversleeps.diario")

    public init(url: URL) { self.url = url }

    public func acrescentar(_ e: Evento) {
        fila.sync {
            guard var dados = try? Diario.codificador.encode(e) else { return }
            dados.append(0x0A)
            let fm = FileManager.default
            try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let h = try? FileHandle(forWritingTo: url) {
                defer { try? h.close() }
                _ = try? h.seekToEnd()
                try? h.write(contentsOf: dados)
            } else {
                try? dados.write(to: url, options: .atomic)
            }
        }
    }

    public func ler() -> [Evento] {
        fila.sync { Diario.decodificar((try? Data(contentsOf: url)) ?? Data()) }
    }

    public func podar(agora: Date = Date()) {
        fila.sync {
            let todos = Diario.decodificar((try? Data(contentsOf: url)) ?? Data())
            let ficam = Diario.podar(todos, agora: agora)
            guard ficam.count != todos.count else { return }
            Diario.gravar(ficam, em: url)
        }
    }

    public func apagar() {
        fila.sync { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: Puro

    public static func podar(_ eventos: [Evento], agora: Date) -> [Evento] {
        let limite = agora.addingTimeInterval(-Double(diasGuardados) * 86_400)
        let recentes = eventos.filter { $0.quando >= limite }
        return Array(recentes.suffix(maximo))
    }

    public static func decodificar(_ dados: Data) -> [Evento] {
        dados.split(separator: 0x0A).compactMap { try? decodificador.decode(Evento.self, from: Data($0)) }
            .sorted { $0.quando < $1.quando }
    }

    static func gravar(_ eventos: [Evento], em url: URL) {
        var dados = Data()
        for e in eventos {
            guard let d = try? codificador.encode(e) else { continue }
            dados.append(d); dados.append(0x0A)
        }
        try? dados.write(to: url, options: .atomic)
    }

    static let codificador: JSONEncoder = {
        let c = JSONEncoder(); c.dateEncodingStrategy = .iso8601; c.outputFormatting = [.sortedKeys]; return c
    }()
    static let decodificador: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    /// O ultimo repouso anotado nos ultimos `minutos`, para o aviso "o Mac
    /// repousou ao fechar a tampa com a trava desligada". Substitui a leitura
    /// de 14 s do `pmset -g log` a cada despertar.
    public static func repousoRecente(_ eventos: [Evento], agora: Date, minutos: Double) -> Evento? {
        eventos.last { $0.tipo == .repousou && $0.quando >= agora.addingTimeInterval(-minutos * 60) }
    }
}

extension Fonte: Codable {
    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        self = s == "bateria" ? .bateria : .tomada
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(self == .bateria ? "bateria" : "tomada")
    }
}

// MARK: - Fita das ultimas horas

public enum Faixa: Equatable {
    case tomada, bateria, repouso, desligado, desconhecido
}

public struct Segmento: Equatable {
    public let inicio: Date
    public let fim: Date
    public let faixa: Faixa
    public init(_ inicio: Date, _ fim: Date, _ faixa: Faixa) {
        self.inicio = inicio; self.fim = fim; self.faixa = faixa
    }
}

public enum Fita {

    /// Reconstroi o estado do Mac entre `de` e `ate` a partir do diario.
    /// Prioridade: desligado > repouso > fonte de energia. Antes do primeiro
    /// evento do diario, o app nao sabe: `desconhecido`, nunca um palpite.
    public static func segmentos(_ todos: [Evento], de: Date, ate: Date, fonteAgora: Fonte?) -> [Segmento] {
        guard ate > de else { return [] }
        // Reinicio inesperado vira um "desligou" sintetico no ultimo sinal.
        var eventos: [Evento] = []
        for e in todos {
            if e.tipo == .reinicioInesperado, let i = e.inicio, i < e.quando { eventos.append(Evento(.desligou, quando: i)) }
            eventos.append(e)
        }
        eventos.sort { $0.quando < $1.quando }
        guard let primeiro = eventos.first, primeiro.quando < ate else {
            return [Segmento(de, ate, .desconhecido)]
        }

        func eEnergia(_ e: Evento) -> Bool { e.tipo == .saiuDaTomada || e.tipo == .voltouATomada }
        // Fonte no inicio: a ultima transicao anterior; senao, o contrario da
        // primeira depois; senao, a fonte de agora.
        var fonte: Fonte? = nil
        if let antes = eventos.last(where: { $0.quando <= de && (eEnergia($0) || $0.fonte != nil) }) {
            fonte = antes.tipo == .saiuDaTomada ? .bateria : antes.tipo == .voltouATomada ? .tomada : antes.fonte
        } else if let depois = eventos.first(where: { $0.quando > de && eEnergia($0) }) {
            fonte = depois.tipo == .saiuDaTomada ? .tomada : .bateria
        } else {
            fonte = fonteAgora
        }
        var dormindo = false, apagado = false
        for e in eventos where e.quando <= de { aplicar(e, &fonte, &dormindo, &apagado) }

        var saida: [Segmento] = []
        func faixa() -> Faixa {
            if apagado { return .desligado }
            if dormindo { return .repouso }
            switch fonte { case .bateria?: return .bateria; case .tomada?: return .tomada; case nil: return .desconhecido }
        }
        func empurrar(_ a: Date, _ b: Date, _ f: Faixa) {
            guard b > a else { return }
            if let u = saida.last, u.faixa == f, u.fim == a { saida[saida.count - 1] = Segmento(u.inicio, b, f) }
            else { saida.append(Segmento(a, b, f)) }
        }

        var cursor = de
        if primeiro.quando > de {
            empurrar(de, primeiro.quando, .desconhecido)
            cursor = primeiro.quando
        }
        for e in eventos where e.quando > de && e.quando <= ate {
            empurrar(cursor, e.quando, faixa())
            aplicar(e, &fonte, &dormindo, &apagado)
            cursor = max(cursor, e.quando)
        }
        empurrar(cursor, ate, faixa())
        return saida
    }

    private static func aplicar(_ e: Evento, _ fonte: inout Fonte?, _ dormindo: inout Bool, _ apagado: inout Bool) {
        switch e.tipo {
        case .saiuDaTomada:  fonte = .bateria
        case .voltouATomada: fonte = .tomada
        case .repousou:      dormindo = true
        case .despertou:     dormindo = false
        case .desligou:      apagado = true; dormindo = false
        case .macLigou, .reinicioInesperado:
            apagado = false; dormindo = false
            if let f = e.fonte { fonte = f }
        default: break
        }
    }
}
