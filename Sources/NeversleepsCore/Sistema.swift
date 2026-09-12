// Sistema.swift — executa o pmset e entrega o Estado. A fonte de verdade.
// Nada aqui e cacheado; quem quer o estado, pergunta ao sistema.
import Foundation

public enum Sistema {

    /// nil = nao consegui executar. Diferente de "" (executou e nao disse nada).
    public static func rodar(_ caminho: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: caminho)
        p.arguments = args
        let saida = Pipe()
        p.standardOutput = saida
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let dados = saida.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        return String(data: dados, encoding: .utf8)
    }

    public static func ler() -> Estado {
        var e = Estado()
        e.trava = lerTrava()
        e.emUso = rodar("/usr/bin/pmset", ["-g", "batt"]).flatMap(Parser.fonteEmUso)
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

    public static func repousosDesde(_ inicio: Date) -> [Repouso] {
        guard let texto = rodar("/usr/bin/pmset", ["-g", "log"]) else { return [] }
        return Parser.repousos(log: texto, desde: inicio)
    }
}
