// Modelo.swift, o vocabulario do app: ajustes, escritas, estado do sistema.
// Sem AppKit. Tudo aqui e testavel com `swift test`.
import Foundation

public enum Tipo {
    case booleana
    case minutos
    case enumerada([(valor: Int, titulo: String)])
}

public enum Escopo {
    case sistema      // global (disablesleep)
    case porFonte     // valor separado para tomada e bateria
}

public enum Fonte: Equatable {
    case tomada, bateria

    public var nomeCurto: String { self == .tomada ? t("tomada") : t("bateria") }
}

/// O que uma escolha do usuario deve deixar em cada fonte. nil = nao mexe.
public struct Escrita: Equatable {
    public let chave: String
    public let tomada: Int?
    public let bateria: Int?

    public init(chave: String, tomada: Int?, bateria: Int?) {
        self.chave = chave; self.tomada = tomada; self.bateria = bateria
    }

    /// Um so comando privilegiado, mesmo quando sao duas fontes: uma autenticacao.
    public var comando: String {
        if let t = tomada, let b = bateria, t == b {
            return "/usr/bin/pmset -a \(chave) \(t)"
        }
        var partes: [String] = []
        if let t = tomada  { partes.append("/usr/bin/pmset -c \(chave) \(t)") }
        if let b = bateria { partes.append("/usr/bin/pmset -b \(chave) \(b)") }
        return partes.joined(separator: " && ")
    }
}

public struct Ajuste {
    public let chave: String
    public let titulo: String
    public let subtitulo: String
    public let aviso: String?          // mostrado antes de DESLIGAR
    public let tipo: Tipo
    public let escopo: Escopo
    public let simbolo: String
}

/// Um repouso registrado pelo sistema.
public struct Repouso: Equatable {
    public let quando: Date
    public let motivo: String
    public init(quando: Date, motivo: String) { self.quando = quando; self.motivo = motivo }

    public var descricao: String {
        let hora = DateFormatter.localizedString(from: quando, dateStyle: .none, timeStyle: .short)
        return "\(hora), \(motivo)"
    }
}

/// Leitura completa do sistema num instante. `trava == nil` = nao consegui ler.
public struct Estado {
    public var tomada: [String: Int] = [:]
    public var bateria: [String: Int] = [:]
    public var trava: Bool? = nil
    public var emUso: Fonte? = nil          // de onde o Mac esta puxando energia AGORA

    public init() {}

    public var leituraOk: Bool { trava != nil && !(tomada.isEmpty && bateria.isEmpty) }

    /// Confere se o sistema ficou como a escrita pediu, fonte por fonte.
    /// A trava (disablesleep) e GLOBAL: vive em `pmset -g`, nao nas secoes de
    /// tomada/bateria. Conferir nas secoes devolvia "nao encontrei" para uma
    /// escrita que tinha dado certo (bug real, 12/09/2026).
    public func confere(_ e: Escrita) -> Bool {
        if e.chave == Catalogo.chaveTrava {
            guard let t = trava, let pedido = e.tomada ?? e.bateria else { return false }
            return t == (pedido == 1)
        }
        if let t = e.tomada,  tomada[e.chave]  != t { return false }
        if let b = e.bateria, bateria[e.chave] != b { return false }
        return true
    }

    /// Texto do que foi encontrado, para o alerta de conferencia.
    public func encontrado(_ e: Escrita) -> String {
        if e.chave == Catalogo.chaveTrava {
            return trava.map { $0 ? t("ligada") : t("desligada") } ?? t("não consegui ler")
        }
        let partes = [tomada[e.chave].map { "\(t("tomada")) \($0)" }, bateria[e.chave].map { "\(t("bateria")) \($0)" }]
            .compactMap { $0 }
        return partes.isEmpty ? t("nada") : partes.joined(separator: ", ")
    }
}

// MARK: - Catalogo
// Declarativo de proposito: acrescentar variavel no futuro e acrescentar uma
// linha aqui. `hibernatefile` aparece no pmset e fica de fora de proposito: e
// um caminho, nao um interruptor.

public enum Catalogo {
    public static let chaveTrava = "disablesleep"
    public static let presetsMinutos = [1, 2, 5, 10, 15, 30, 60]

    public static var tampa: Ajuste {
        Ajuste(chave: chaveTrava,
               titulo: t("Impedir Repouso ao Fechar a Tampa"),
               subtitulo: "",
               aviso: t("Ligada, a trava impede o Mac de repousar sozinho, mesmo fechado. Não o guarde na mochila com ela ligada: esquenta e consome a bateria."),
               tipo: .booleana, escopo: .sistema, simbolo: "laptopcomputer")
    }

    public static var ajustes: [Ajuste] { [
        Ajuste(chave: "sleep", titulo: t("Repousar Após"),
               subtitulo: t("Tempo de inatividade até o Mac repousar"),
               aviso: nil, tipo: .minutos, escopo: .porFonte, simbolo: "powersleep"),

        Ajuste(chave: "displaysleep", titulo: t("Desligar a Tela Após"),
               subtitulo: t("A tela desliga, o trabalho continua"),
               aviso: nil, tipo: .minutos, escopo: .porFonte, simbolo: "display"),

        Ajuste(chave: "disksleep", titulo: t("Repousar os Discos Após"),
               subtitulo: t("Em SSD o ganho é pequeno"),
               aviso: nil, tipo: .minutos, escopo: .porFonte, simbolo: "internaldrive"),

        Ajuste(chave: "powernap", titulo: t("Power Nap"),
               subtitulo: t("Busca e-mail e faz backup em repouso"),
               aviso: nil, tipo: .booleana, escopo: .porFonte, simbolo: "moon.stars"),

        Ajuste(chave: "standby", titulo: t("Standby Após Repouso Longo"),
               subtitulo: t("Salva no disco e corta a energia após horas em repouso"),
               aviso: nil, tipo: .booleana, escopo: .porFonte, simbolo: "bed.double"),

        Ajuste(chave: "womp", titulo: t("Despertar para Acesso de Rede"),
               subtitulo: t("Acorda quando acessam o Mac pela rede"),
               aviso: nil, tipo: .booleana, escopo: .porFonte, simbolo: "network"),

        Ajuste(chave: "tcpkeepalive", titulo: t("Manter a Rede Ativa em Repouso"),
               subtitulo: t("Buscar, iMessage e Handoff continuam funcionando"),
               aviso: t("Desligar quebra o Buscar: se perder o Mac, ele não aparece no mapa."),
               tipo: .booleana, escopo: .porFonte, simbolo: "wifi"),

        Ajuste(chave: "ttyskeepawake", titulo: t("Não Repousar com Terminal Ativo"),
               subtitulo: t("Segura o repouso enquanto há sessão de terminal aberta"),
               aviso: nil, tipo: .booleana, escopo: .porFonte, simbolo: "terminal"),

        Ajuste(chave: "lowpowermode", titulo: t("Modo Pouca Energia"),
               subtitulo: t("Menos desempenho, mais bateria"),
               aviso: nil, tipo: .booleana, escopo: .porFonte, simbolo: "battery.25"),

        Ajuste(chave: "lessbright", titulo: t("Escurecer Levemente a Tela na Bateria"),
               subtitulo: t("Reduz o brilho ao sair da tomada"),
               aviso: nil, tipo: .booleana, escopo: .porFonte, simbolo: "sun.min"),

        Ajuste(chave: "hibernatemode", titulo: t("Como Salvar a Memória em Repouso"),
               subtitulo: "",
               aviso: nil,
               tipo: .enumerada([
                   (0,  t("Só na Memória (acorda rápido)")),
                   (3,  t("Memória e Disco (padrão)")),
                   (25, t("Só no Disco (acorda devagar)"))
               ]),
               escopo: .porFonte, simbolo: "archivebox")
    ] }

    /// Chaves do catalogo, usadas pelo parser para saber onde esta o valor.
    public static let chavesConhecidas: Set<String> = [
        "sleep", "displaysleep", "disksleep", "powernap", "standby", "womp",
        "tcpkeepalive", "ttyskeepawake", "lowpowermode", "lessbright", "hibernatemode"
    ]
}

public func rotuloMinutos(_ n: Int) -> String { n == 0 ? t("Nunca") : tf("%d min", n) }
