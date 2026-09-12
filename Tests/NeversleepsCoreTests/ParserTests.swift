// ParserTests.swift — Swift Testing (XCTest nao existe nas Command Line Tools).
// Cada teste aqui corresponde a um comportamento que ja quebrou ou quase quebrou.
import Testing
import Foundation
@testable import NeversleepsCore

private func data(_ s: String) -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
    return f.date(from: s)!
}

@Suite struct ParserTests {

    @Test func customSeparaTomadaEBateria() {
        let (t, b) = Parser.custom(Amostras.custom)
        #expect(t["womp"] == 1, "womp na tomada")
        #expect(b["womp"] == 0, "womp na bateria")
        #expect(t["disksleep"] == 10)
        #expect(b["sleep"] == 1)
    }

    @Test func customChaveSoNaBateria() {
        let (t, b) = Parser.custom(Amostras.custom)
        #expect(t["lessbright"] == nil, "lessbright nao existe na tomada")
        #expect(b["lessbright"] == 1)
    }

    @Test func customIgnoraValoresQueNaoSaoNumero() {
        let (t, _) = Parser.custom(Amostras.custom)
        #expect(t["hibernatefile"] == nil, "caminho nao e interruptor")
    }

    @Test func customChaveCompostaUsaUltimoCampo() {
        let (t, _) = Parser.custom(Amostras.custom)
        #expect(t["Sleep On Power Button"] == 1)
    }

    /// Bug real nº 1: "sleep 1 (sleep prevented by ...)" perdia a chave.
    @Test func anotacaoDepoisDoValorNaoQuebraAChave() {
        let (t, _) = Parser.custom("AC Power:\n sleep 1 (sleep prevented by powerd, Claude)\n")
        #expect(t["sleep"] == 1)
    }

    @Test func trava() {
        #expect(Parser.trava(Amostras.geralComTrava) == true)
        #expect(Parser.trava(Amostras.geralSemTrava) == false)
        #expect(Parser.trava(Amostras.geral) == nil, "sem a linha SleepDisabled, nao sei")
    }

    @Test func fonteEmUso() {
        #expect(Parser.fonteEmUso(Amostras.battBateria) == .bateria)
        #expect(Parser.fonteEmUso(Amostras.battTomada) == .tomada)
        #expect(Parser.fonteEmUso("") == nil)
    }

    @Test func repousosDesdeFiltraPorInicio() {
        let r = Parser.repousos(log: Amostras.log, desde: data("2026-09-12 09:00:00 -0300"))
        #expect(r.count == 1, "so o Clamshell das 09:09; o Maintenance das 07:15 fica de fora")
        #expect(r.first?.motivo == "Clamshell Sleep")
    }

    @Test func repousosSemNadaDepoisDoInicio() {
        #expect(Parser.repousos(log: Amostras.log, desde: Date()).isEmpty)
    }
}

@Suite struct ModeloTests {

    @Test func escritaMesmoValorNasDuasUsaMenosA() {
        #expect(Escrita(chave: "womp", tomada: 1, bateria: 1).comando == "/usr/bin/pmset -a womp 1")
    }

    @Test func escritaValoresDiferentesEncadeia() {
        #expect(Escrita(chave: "womp", tomada: 1, bateria: 0).comando
                == "/usr/bin/pmset -c womp 1 && /usr/bin/pmset -b womp 0")
    }

    @Test func escritaSoUmaFonte() {
        #expect(Escrita(chave: "sleep", tomada: nil, bateria: 5).comando == "/usr/bin/pmset -b sleep 5")
    }

    /// Bug real nº 2: a trava e global; conferir nas secoes dava "nao aplicou" falso.
    @Test func confereTravaOlhaOCampoGlobal() {
        var e = Estado()
        e.trava = true
        #expect(e.confere(Escrita(chave: "disablesleep", tomada: 1, bateria: 1)))
        #expect(!e.confere(Escrita(chave: "disablesleep", tomada: 0, bateria: 0)))
        e.trava = nil
        #expect(!e.confere(Escrita(chave: "disablesleep", tomada: 1, bateria: 1)), "sem leitura, nao confirma")
    }

    @Test func conferePorFonte() {
        var e = Estado()
        e.tomada = ["womp": 1]; e.bateria = ["womp": 0]
        #expect(e.confere(Escrita(chave: "womp", tomada: 1, bateria: 0)))
        #expect(!e.confere(Escrita(chave: "womp", tomada: 1, bateria: 1)))
        #expect(e.confere(Escrita(chave: "womp", tomada: nil, bateria: 0)), "nil = nao mexi, nao confere")
    }

    @Test func leituraOk() {
        var e = Estado()
        #expect(!e.leituraOk)
        e.trava = false; e.tomada = ["sleep": 1]
        #expect(e.leituraOk)
    }
}
