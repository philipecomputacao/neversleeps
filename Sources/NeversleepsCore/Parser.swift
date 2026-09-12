// Parser.swift, le a SAIDA do pmset, sem executar nada. Funcoes puras.
//
// E aqui que moram os dois bugs que ja morderam: a chave anotada
// ("sleep 1 (sleep prevented by ...)") e a trava que nao esta nas secoes.
// Por isso tudo aqui e testado com saidas reais em Tests/.
import Foundation

public enum Parser {

    /// `pmset -g custom` -> (tomada, bateria).
    public static func custom(_ texto: String) -> (tomada: [String: Int], bateria: [String: Int]) {
        var tomada: [String: Int] = [:], bateria: [String: Int] = [:]
        var secao = ""
        for linha in texto.split(separator: "\n") {
            let t = linha.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { continue }
            if t.hasSuffix(":") { secao = String(t.dropLast()); continue }

            let campos = t.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard campos.count >= 2 else { continue }

            // Chave conhecida: o valor e o SEGUNDO campo, mesmo que venha anotacao
            // depois. Chave composta ("Sleep On Power Button 1"): o ultimo campo.
            let chave: String, bruto: String
            if Catalogo.chavesConhecidas.contains(campos[0]) {
                chave = campos[0]; bruto = campos[1]
            } else {
                chave = campos.dropLast().joined(separator: " "); bruto = campos[campos.count - 1]
            }
            guard let n = Int(bruto) else { continue }

            if secao == "AC Power" { tomada[chave] = n }
            else if secao == "Battery Power" { bateria[chave] = n }
        }
        return (tomada, bateria)
    }

    /// `pmset -g` -> SleepDisabled. nil = a linha nao existe na saida.
    public static func trava(_ texto: String) -> Bool? {
        for linha in texto.split(separator: "\n") {
            let t = linha.trimmingCharacters(in: .whitespaces)
            if t.lowercased().hasPrefix("sleepdisabled") { return t.hasSuffix("1") }
        }
        return nil
    }

    /// `pmset -g batt` -> "Now drawing from 'Battery Power'" / "'AC Power'".
    public static func fonteEmUso(_ texto: String) -> Fonte? {
        guard let primeira = texto.split(separator: "\n").first else { return nil }
        if primeira.contains("Battery Power") { return .bateria }
        if primeira.contains("AC Power") { return .tomada }
        return nil
    }

    /// `pmset -g log` -> linhas "Entering Sleep" com carimbo >= inicio.
    /// E a testemunha independente do teste da tampa: se o Mac repousou, esta aqui.
    public static func repousos(log texto: String, desde inicio: Date) -> [Repouso] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        var achados: [Repouso] = []
        for linha in texto.split(separator: "\n") where linha.contains("Entering Sleep") {
            let carimbo = linha.prefix(25)                  // "2026-09-10 12:34:31 -0300"
            guard let quando = f.date(from: String(carimbo)), quando >= inicio else { continue }
            let motivo = linha.range(of: "due to '").map { r -> String in
                let resto = linha[r.upperBound...]
                return String(resto.prefix { $0 != "'" })
            } ?? t("repouso")
            achados.append(Repouso(quando: quando, motivo: motivo))
        }
        return achados
    }
}
