// =============================================================================
//  neversleeps: mantem o Mac trabalhando com a tampa fechada
//  LP Digital (@lpdigital.me), MIT
// =============================================================================
//
//  MAPA DO CODIGO
//  --------------
//  Sources/NeversleepsCore/   nucleo sem AppKit, testado por `swift test`
//    Modelo.swift             ajustes, escritas, estado, catalogo
//    Parser.swift             le a SAIDA do pmset (funcoes puras)
//    Sistema.swift            executa o pmset e entrega o Estado
//    Localizacao.swift        t() / tf(): chaves em pt-BR, traducao em Recursos/
//  Sources/neversleeps/       o app
//    main.swift               este arquivo: modos de linha de comando e partida
//    Controlador.swift        icone, menu, orientacao de primeira vez
//    Controlador+Teste.swift  o teste da tampa
//    Privilegio.swift         escrita como root pelo dialogo do macOS
//    Prefs.swift              preferencias do app (nunca o estado do sistema)
//    Dialogos.swift           alertas no idioma da Apple
//    JanelaAjustes.swift      Ajustes de Energia (⌘,)
//    JanelaAjuda.swift        Ajuda (⇧⌘?)
//    JanelaSobre.swift        Sobre
//
//  COMO O APP FUNCIONA (o essencial)
//  ---------------------------------
//  1. LE o estado real chamando `pmset -g`, `pmset -g custom`, `pmset -g batt`.
//  2. ESCREVE chamando `pmset` como root pelo dialogo de autenticacao do
//     proprio sistema, uma autenticacao por alteracao (ou por lote, na janela).
//  3. RELE depois de escrever. Se o macOS aceitou e ignorou, o usuario sabe.
//  Nunca guarda o estado do sistema como fonte de verdade. Nunca usa a rede.
//
//  MODOS DE LINHA DE COMANDO
//  -------------------------
//  neversleeps --estado               imprime o que o app le do sistema
//  neversleeps --repousos <minutos>   repousos do log nos ultimos N minutos
//  neversleeps --desregistrar-login   tira o app dos Itens de Inicio de Sessao
//  (binario em /Applications/neversleeps.app/Contents/MacOS/neversleeps)
//
//  A documentacao completa esta no README e na janela Ajuda.
// =============================================================================

import Cocoa
import ServiceManagement
import NeversleepsCore

// MARK: - Modos de linha de comando

if CommandLine.arguments.contains("--estado") {
    let e = Sistema.ler()
    print("leitura ok: \(e.leituraOk)")
    print("trava da tampa (disablesleep): \(e.trava.map { $0 ? "1" : "0" } ?? "NAO LI")")
    print("fonte em uso agora: \(e.emUso?.nomeCurto ?? "NAO LI")")
    print("")
    print("  chave            tomada  bateria  titulo")
    for a in Catalogo.ajustes {
        let t = e.tomada[a.chave].map(String.init) ?? "-"
        let b = e.bateria[a.chave].map(String.init) ?? "-"
        if t == "-" && b == "-" { continue }
        print("  \(a.chave.padding(toLength: 16, withPad: " ", startingAt: 0)) \(t.padding(toLength: 7, withPad: " ", startingAt: 0)) \(b.padding(toLength: 8, withPad: " ", startingAt: 0)) \(a.titulo)")
    }
    exit(0)
}

if let i = CommandLine.arguments.firstIndex(of: "--repousos"),
   i + 1 < CommandLine.arguments.count, let min = Int(CommandLine.arguments[i + 1]) {
    let r = Sistema.repousosDesde(Date().addingTimeInterval(-Double(min) * 60))
    print("repousos nos ultimos \(min) min: \(r.count)")
    for l in r { print("  \(l.descricao)") }
    exit(0)
}

if CommandLine.arguments.contains("--desregistrar-login") {
    do {
        try SMAppService.mainApp.unregister()
        print("Item de inicio de sessao removido.")
    } catch {
        print("Nada a remover ou nao foi possivel: \(error.localizedDescription)")
    }
    exit(0)
}

#if DEBUG
// So em build de debug: abre as janelas e imprime o tamanho, para conferir a
// montagem sem clicar. Nao existe no binario de release.
let diagnosticoJanelas = CommandLine.arguments.contains("--diagnostico-janelas")
#endif

// MARK: - Partida

let app = NSApplication.shared
let controlador = Controlador()
app.delegate = controlador
app.setActivationPolicy(.accessory)   // sem icone na Dock, sem janela principal
#if DEBUG
if let i = CommandLine.arguments.firstIndex(of: "--capturar"), i + 1 < CommandLine.arguments.count {
    let pasta = CommandLine.arguments[i + 1]
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { controlador.capturarJanelas(em: pasta) }
    // Timer em .common: dispara mesmo com o menu aberto (asyncAfter nao dispararia).
    RunLoop.main.add(Timer(timeInterval: 10.0, repeats: false) { _ in print("tempo esgotado"); exit(1) }, forMode: .common)
}
if diagnosticoJanelas {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        controlador.diagnosticoJanelas()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { exit(0) }
    }
}
#endif
app.run()
