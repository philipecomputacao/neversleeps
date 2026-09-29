// Sistema.swift, executa o pmset e entrega o Estado. A fonte de verdade.
// Nada aqui e cacheado; quem quer o estado, pergunta ao sistema.
import Foundation

public enum Sistema {

    /// nil = nao consegui executar. Diferente de "" (executou e nao disse nada).
    public static func rodar(_ caminho: String, _ args: [String]) -> String? {
        guard let r = rodarCompleto(caminho, args), r.codigo == 0 else { return nil }
        return r.saida
    }

    /// Para os comandos em que o codigo de saida diz algo (nvram, launchctl).
    public static func rodarCompleto(_ caminho: String, _ args: [String])
        -> (codigo: Int32, saida: String, erro: String)? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: caminho)
        p.arguments = args
        let saida = Pipe(), erro = Pipe()
        p.standardOutput = saida
        p.standardError = erro
        do { try p.run() } catch { return nil }
        // Le as duas saidas antes de esperar: pipe cheio trava o processo filho.
        let dados = saida.fileHandleForReading.readDataToEndOfFile()
        let dadosErro = erro.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus,
                String(data: dados, encoding: .utf8) ?? "",
                String(data: dadosErro, encoding: .utf8) ?? "")
    }

    public static func ler() -> Estado {
        var e = Estado()
        e.trava = lerTrava()
        if let batt = rodar("/usr/bin/pmset", ["-g", "batt"]) {
            e.emUso = Parser.fonteEmUso(batt)
            e.carga = Parser.carga(batt)
        }
        if let texto = rodar("/usr/bin/pmset", ["-g", "custom"]) {
            let (t, b) = Parser.custom(texto)
            e.tomada = t; e.bateria = b
        }
        return e
    }

    /// So a trava. Barato o bastante para rodar num timer.
    public static func lerTrava() -> Bool? {
        rodar("/usr/bin/pmset", ["-g"]).flatMap(Parser.trava)
    }

    /// Fonte e carga, para o registro da falta de energia.
    public static func lerBateria() -> (fonte: Fonte?, carga: Int?) {
        guard let batt = rodar("/usr/bin/pmset", ["-g", "batt"]) else { return (nil, nil) }
        return (Parser.fonteEmUso(batt), Parser.carga(batt))
    }

    public static func repousosDesde(_ inicio: Date) -> [Repouso] {
        guard let texto = rodar("/usr/bin/pmset", ["-g", "log"]) else { return [] }
        return Parser.repousos(log: texto, desde: inicio)
    }

    // MARK: Falta de energia

    /// nil = nao consegui ler. A variavel ausente e o caso comum (padrao do
    /// macOS): o nvram sai com 1 e diz "data was not found" no stderr.
    public static func lerPartida() -> PartidaAutomatica? {
        guard let r = rodarCompleto("/usr/sbin/nvram", ["BootPreference"]) else { return nil }
        if r.codigo == 0 { return Parser.bootPreference(r.saida).flatMap { PartidaAutomatica(byte: $0) } }
        if r.erro.contains("data was not found") { return .padrao }
        return nil
    }

    public static func fileVaultLigado() -> Bool? {
        rodar("/usr/bin/fdesetup", ["status"]).flatMap(Parser.fileVault)
    }

    /// Servico do launchd carregado no dominio do sistema. Medido: o sshd so
    /// esta carregado com o Acesso Remoto ligado; o screensharing, com o
    /// Compartilhamento de Tela. `launchctl print` sai com 0 (carregado) ou
    /// 113 (nao existe). Sem senha, sem abrir porta.
    public static func servicoLigado(_ rotulo: String) -> Bool? {
        guard let r = rodarCompleto("/bin/launchctl", ["print", "system/\(rotulo)"]) else { return nil }
        if r.codigo == 0 { return true }
        if r.codigo == 113 { return false }
        return nil
    }

    public static func acessoRemotoLigado() -> Bool? { servicoLigado("com.openssh.sshd") }
    public static func compartilhamentoDeTelaLigado() -> Bool? { servicoLigado("com.apple.screensharing") }

    /// kern.boottime em segundos. Muda a cada partida do Mac, e so a cada partida.
    public static func partidaAtual() -> Double? {
        var tv = timeval()
        var tamanho = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &tv, &tamanho, nil, 0) == 0 else { return nil }
        return Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000
    }

    /// Nome para o `ssh usuario@nome.local`.
    public static func nomeLocal() -> String? {
        rodar("/usr/sbin/scutil", ["--get", "LocalHostName"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
