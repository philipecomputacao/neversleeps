// Energia.swift, o modulo Falta de Energia: ligar sozinho, reconhecer um
// reinicio inesperado, contar o que aconteceu e retomar o trabalho.
// Sem AppKit. As decisoes moram aqui como funcoes puras, testadas em Tests/ e
// no alvo `verificar`.
//
// O QUE FOI MEDIDO ANTES DE ESCREVER (29/09/2026, M1, macOS 26.2)
// - `autorestart` nao existe em MacBook (`pmset -g cap` nao lista). Num
//   notebook, quem liga depois da queda e o BootPreference da NVRAM: sem a
//   variavel, o Mac com chip Apple liga ao conectar o carregador ou abrir a
//   tampa (Apple, suporte 120622, macOS 15 ou superior).
// - Com a trava ligada o kernel recusa QUALQUER repouso, inclusive o de
//   emergencia por bateria baixa: em IOPMrootDomain::checkSystemSleepAllowed o
//   teste `userDisabledAllSleep` vem antes da excecao `lowBatteryCondition`.
//   Entao a bateria acaba com tudo rodando; nao ha como salvar o processo.
//   O que o app faz e registrar, religar e retomar.
// - Com FileVault ligado, um reinicio para na tela de desbloqueio, antes do
//   macOS carregar. No macOS 26 da para desbloquear por SSH se o Acesso Remoto
//   estiver ligado; depois disso o Mac para na janela de login.
import Foundation

// MARK: - Ligar sozinho (nvram BootPreference)

/// O que o Mac faz quando esta desligado e recebe energia ou tem a tampa aberta.
public struct PartidaAutomatica: Equatable {
    public var aoConectarCarregador: Bool
    public var aoAbrirTampa: Bool

    public init(aoConectarCarregador: Bool, aoAbrirTampa: Bool) {
        self.aoConectarCarregador = aoConectarCarregador
        self.aoAbrirTampa = aoAbrirTampa
    }

    /// O padrao do macOS (variavel ausente): liga nos dois casos.
    public static let padrao = PartidaAutomatica(aoConectarCarregador: true, aoAbrirTampa: true)

    /// Valores da Apple: %00 impede os dois, %01 impede so a tampa, %02 impede
    /// so o carregador. `nil` = variavel ausente (padrao).
    public var byte: UInt8? {
        switch (aoConectarCarregador, aoAbrirTampa) {
        case (true, true):   return nil
        case (true, false):  return 0x01
        case (false, true):  return 0x02
        case (false, false): return 0x00
        }
    }

    public init?(byte: UInt8?) {
        switch byte {
        case nil:  self = .padrao
        case 0x00: self.init(aoConectarCarregador: false, aoAbrirTampa: false)
        case 0x01: self.init(aoConectarCarregador: true, aoAbrirTampa: false)
        case 0x02: self.init(aoConectarCarregador: false, aoAbrirTampa: true)
        default:   return nil          // valor que a Apple nao documenta: nao adivinho
        }
    }

    /// Comando privilegiado. Texto fixo e um byte do enum, nunca entrada livre.
    public var comando: String {
        guard let b = byte else { return "/usr/sbin/nvram -d BootPreference" }
        return String(format: "/usr/sbin/nvram BootPreference=%%%02x", b)
    }
}

// MARK: - Reinicio inesperado

public enum Reinicio {

    public enum Veredito: Equatable {
        case mesmaPartida      // o app reabriu sem o Mac reiniciar
        case primeiraVez       // nao ha partida anterior registrada
        case encerradoNormal   // o app viu o proprio fim naquela partida (desligar, reiniciar, Encerrar)
        case inesperado        // o Mac voltou sem o app ter visto o fim da partida anterior
    }

    /// `bootAtual`: kern.boottime agora. `bootConhecido`: o ultimo que o app
    /// registrou. `encerradoNoBoot`: o boottime da partida em que o app viu o
    /// proprio fim (`applicationWillTerminate` ou `willPowerOff`). Desligar ou
    /// reiniciar pelo menu encerra os apps, entao cai aqui; queda de energia,
    /// panico do kernel e botao segurado nao encerram ninguem.
    /// Limite conhecido: se o usuario Encerrar o app e o Mac cair depois, o
    /// app nao estava la para ver, e nao acusa nada.
    public static func avaliar(bootAtual: Double, bootConhecido: Double?,
                               encerradoNoBoot: Double?) -> Veredito {
        guard let anterior = bootConhecido else { return .primeiraVez }
        // Tolerancia de 1 s: o boottime e estavel, mas vem com microssegundos.
        if abs(bootAtual - anterior) < 1 { return .mesmaPartida }
        if let fim = encerradoNoBoot, abs(fim - anterior) < 1 { return .encerradoNormal }
        return .inesperado
    }
}

/// Um periodo na bateria, observado pelo app. Pode ser falta de energia ou o
/// cabo tirado de proposito: o app nao sabe a diferenca e nao finge saber.
public struct PeriodoNaBateria: Codable, Equatable {
    public var inicio: Date
    public var bateriaInicio: Int?
    public var ultimaLeitura: Date
    public var ultimaBateria: Int?
    public var fim: Date?            // nil = o Mac ainda estava na bateria no ultimo registro

    public init(inicio: Date, bateriaInicio: Int?) {
        self.inicio = inicio; self.bateriaInicio = bateriaInicio
        self.ultimaLeitura = inicio; self.ultimaBateria = bateriaInicio
    }
}

public enum CausaProvavel: Equatable {
    case bateriaAcabou     // estava na bateria, sem fim registrado, ultima leitura baixa
    case estavaNaBateria   // estava na bateria, mas a carga nao explica o desligamento
    case desconhecida      // estava na tomada: travamento, panico do kernel, botao
}

public enum Relato {
    /// Carga abaixo da qual "a bateria acabou" e a explicacao honesta.
    public static let limiteBateriaAcabou = 10

    public static func causa(_ periodo: PeriodoNaBateria?) -> CausaProvavel {
        guard let p = periodo, p.fim == nil else { return .desconhecida }
        if let b = p.ultimaBateria, b <= limiteBateriaAcabou { return .bateriaAcabou }
        return .estavaNaBateria
    }
}

// MARK: - Retomar o trabalho

/// Uma tarefa que o app reabre no Terminal depois de um reinicio inesperado.
/// O comando e texto livre do USUARIO e roda como ele, nunca como root, nunca
/// pelo Privilegio.
public struct Tarefa: Codable, Equatable {
    public var pasta: String
    public var comando: String

    public init(pasta: String, comando: String) {
        self.pasta = pasta; self.comando = comando
    }

    public static let comandoSugerido = "claude --continue"

    public var valida: Bool {
        !pasta.trimmingCharacters(in: .whitespaces).isEmpty
            && !comando.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Aspas simples no shell: tudo literal; a aspa simples vira '\''.
    public static func aspas(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Conteudo do arquivo .command que o Terminal executa. O `~` no inicio da
    /// pasta e expandido aqui, porque dentro de aspas o shell nao expande.
    public func script(casa: String) -> String {
        var p = pasta.trimmingCharacters(in: .whitespaces)
        if p == "~" { p = casa } else if p.hasPrefix("~/") { p = casa + String(p.dropFirst()) }
        return """
        #!/bin/zsh -l
        # neversleeps: retomada depois de um reinicio inesperado.
        # Gerado pelo app; editar aqui nao adianta, edite em Falta de Energia.
        cd \(Tarefa.aspas(p)) || { echo "neversleeps: pasta nao encontrada."; exit 1; }
        \(comando.trimmingCharacters(in: .whitespacesAndNewlines))

        """
    }
}
