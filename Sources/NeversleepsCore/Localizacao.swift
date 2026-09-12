// Localizacao.swift, chaves em pt-BR, traducoes em Recursos/<idioma>.lproj.
//
// A chave E o texto em portugues (idioma de desenvolvimento). Quando o sistema
// esta em outro idioma, o bundle procura a traducao em <idioma>.lproj; se nao
// houver, devolve a chave. Nos testes (sem bundle), devolve a chave.
import Foundation

/// Texto localizado.
public func t(_ chave: String) -> String {
    NSLocalizedString(chave, bundle: .main, comment: "")
}

/// Texto localizado com formato (%@, %d).
public func tf(_ chave: String, _ args: CVarArg...) -> String {
    String(format: t(chave), locale: .current, arguments: args)
}
