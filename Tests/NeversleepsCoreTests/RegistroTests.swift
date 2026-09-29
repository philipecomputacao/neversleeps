// RegistroTests.swift, o Historico: frases, fita e diario em disco. Mesmo
// conjunto do alvo `verificar`, em Swift Testing (roda no CI).
import Testing
import Foundation
@testable import NeversleepsCore

private let base: Date = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
    return f.date(from: "2026-09-28 10:00:00 -0300")!
}()
private func em(_ min: Double) -> Date { base.addingTimeInterval(min * 60) }
private func ev(_ tipo: TipoEvento, _ min: Double, _ ajuste: (inout Evento) -> Void = { _ in }) -> Evento {
    var e = Evento(tipo, quando: em(min)); ajuste(&e); return e
}

@Suite struct RegistroTests {

    @Test func duracaoLegivel() {
        #expect(Evento.duracao(45) == "45 s")
        #expect(Evento.duracao(720) == "12 min")
        #expect(Evento.duracao(72) == "1 min 12 s", "no teste da tampa os segundos contam")
        #expect(Evento.duracao(8040) == "2 h 14 min")
        #expect(Evento.duracao(7200) == "2 h")
    }

    @Test func frases() {
        #expect(ev(.repousou, 0) { $0.porTampa = true; $0.trava = false }.descricao == "A trava estava desligada")
        #expect(ev(.voltouATomada, 0) { $0.duracao = 3000; $0.cargaInicial = 90; $0.carga = 71 }.descricao
                == "50 min na bateria · 90% → 71%")
        #expect(ev(.retomada, 0).categoria == .reinicios)
        #expect(ev(.ajustesAplicados, 0) { $0.chaves = ["powernap", "naoexiste"] }.descricao == "Power Nap",
                "guarda a chave, traduz na hora de mostrar")
        #expect(ev(.retomada, 0) { $0.abertas = 1; $0.total = 2 }.selo == "1 de 2 abertas")
        #expect(ev(.retomada, 0).selo == nil)
    }

    @Test func fitaSemDiarioNaoAdivinha() {
        #expect(Fita.segmentos([], de: base, ate: em(600), fonteAgora: .tomada) == [Segmento(base, em(600), .desconhecido)])
    }

    @Test func fitaDeUmDia() {
        let dia = [ev(.appAbriu, 0), ev(.saiuDaTomada, 60), ev(.repousou, 90), ev(.despertou, 120), ev(.voltouATomada, 180)]
        let f = Fita.segmentos(dia, de: base, ate: em(600), fonteAgora: .tomada)
        #expect(f.map { $0.faixa } == [.tomada, .bateria, .repouso, .bateria, .tomada])
        #expect(f.first?.inicio == base && f.last?.fim == em(600))
    }

    @Test func reinicioInesperadoPintaDesligado() {
        let queda = [ev(.appAbriu, 0), ev(.saiuDaTomada, 10),
                     ev(.reinicioInesperado, 300) { $0.inicio = em(200); $0.fonte = .tomada }]
        let h = Fita.segmentos(queda, de: base, ate: em(600), fonteAgora: .tomada)
        #expect(h.map { $0.faixa } == [.tomada, .bateria, .desligado, .tomada])
        #expect(h[2].inicio == em(200) && h[2].fim == em(300))
    }

    @Test func diarioEmDisco() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ns-teste-\(UUID().uuidString).jsonl")
        let d = Diario(url: url)
        d.acrescentar(ev(.saiuDaTomada, 1) { $0.carga = 80 })
        d.acrescentar(ev(.appAbriu, 0))
        let h = try FileHandle(forWritingTo: url)
        _ = try h.seekToEnd(); try h.write(contentsOf: Data("{lixo}\n".utf8)); try h.close()
        let lidos = d.ler()
        #expect(lidos.count == 2, "linha ruim ignorada")
        #expect(lidos.first?.tipo == .appAbriu, "ordenado por hora")
        d.apagar()
        #expect(d.ler().isEmpty)
    }

    @Test func poda() {
        #expect(Diario.podar([ev(.appAbriu, -60 * 24 * 31), ev(.appAbriu, 0)], agora: base).count == 1)
    }
}
