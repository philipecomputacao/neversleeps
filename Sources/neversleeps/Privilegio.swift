// Privilegio.swift, escrita como root pelo dialogo de autenticacao do macOS.
import Cocoa
import NeversleepsCore

enum Resultado {
    case ok
    case cancelado
    case falha(String)
}

enum Privilegio {

    /// Roda um comando como root pelo dialogo de autenticacao do macOS.
    /// Executa DENTRO do processo (NSAppleScript), por isso o dialogo diz
    /// "neversleeps deseja fazer alteracoes" e mostra o icone do app, com
    /// `osascript` em subprocesso ele diria "osascript", com icone generico.
    /// O texto do comando vem do catalogo e de inteiros, nunca de entrada livre.
    static func rodar(_ comando: String) -> Resultado {
        let escapado = comando
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let fonte = "do shell script \"\(escapado)\" with administrator privileges"

        guard let script = NSAppleScript(source: fonte) else {
            return .falha(t("Não foi possível preparar o comando."))
        }
        // A API devolve sempre um descritor; o sinal de falha e o dicionario de erro.
        var erro: NSDictionary?
        _ = script.executeAndReturnError(&erro)
        if erro == nil { return .ok }

        // -128 e exatamente "o usuario cancelou". Cancelar e uso normal.
        if let n = erro?[NSAppleScript.errorNumber] as? Int, n == -128 { return .cancelado }
        let msg = (erro?[NSAppleScript.errorMessage] as? String) ?? t("Erro desconhecido.")
        return .falha(msg)
    }
}
