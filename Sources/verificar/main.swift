// verificar — as checagens do nucleo SEM framework de teste, para rodar em
// qualquer Mac so com as Command Line Tools (XCTest e Testing exigem Xcode).
// E o mesmo conjunto de Tests/NeversleepsCoreTests, em forma de portao:
// `swift run verificar` sai com 1 se algo falhar. O construir.sh chama isto.
import Foundation
import NeversleepsCore

var falhas = 0
func check(_ ok: Bool, _ nome: String) {
    print((ok ? "  ok    " : "  FALHA ") + nome)
    if !ok { falhas += 1 }
}
func data(_ s: String) -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
    return f.date(from: s)!
}

print("Parser")
do {
    let (t, b) = Parser.custom(Amostras.custom)
    check(t["womp"] == 1 && b["womp"] == 0, "custom separa tomada e bateria (womp 1/0)")
    check(t["lessbright"] == nil && b["lessbright"] == 1, "lessbright so na bateria")
    check(t["hibernatefile"] == nil, "caminho nao e interruptor")
    check(t["Sleep On Power Button"] == 1, "chave composta usa o ultimo campo")
    let (a, _) = Parser.custom("AC Power:\n sleep 1 (sleep prevented by powerd, Claude)\n")
    check(a["sleep"] == 1, "anotacao depois do valor nao quebra a chave (bug real 1)")
    check(Parser.trava(Amostras.geralComTrava) == true && Parser.trava(Amostras.geralSemTrava) == false, "trava 1/0")
    check(Parser.trava(Amostras.geral) == nil, "sem SleepDisabled = nao sei")
    check(Parser.fonteEmUso(Amostras.battBateria) == .bateria && Parser.fonteEmUso(Amostras.battTomada) == .tomada, "fonte em uso")
    let r = Parser.repousos(log: Amostras.log, desde: data("2026-09-12 09:00:00 -0300"))
    check(r.count == 1 && r.first?.motivo == "Clamshell Sleep", "repousos desde o inicio (so o Clamshell)")
    check(Parser.repousos(log: Amostras.log, desde: Date()).isEmpty, "nenhum repouso depois de agora")
}

print("Modelo")
do {
    check(Escrita(chave: "womp", tomada: 1, bateria: 1).comando == "/usr/bin/pmset -a womp 1", "mesmo valor usa -a")
    check(Escrita(chave: "womp", tomada: 1, bateria: 0).comando == "/usr/bin/pmset -c womp 1 && /usr/bin/pmset -b womp 0", "valores diferentes encadeiam")
    check(Escrita(chave: "sleep", tomada: nil, bateria: 5).comando == "/usr/bin/pmset -b sleep 5", "so uma fonte")
    var e = Estado(); e.trava = true
    check(e.confere(Escrita(chave: "disablesleep", tomada: 1, bateria: 1)), "confere a trava no campo global (bug real 2)")
    check(!e.confere(Escrita(chave: "disablesleep", tomada: 0, bateria: 0)), "trava pedida 0 com trava 1 nao confere")
    e.trava = nil
    check(!e.confere(Escrita(chave: "disablesleep", tomada: 1, bateria: 1)), "sem leitura nao confirma")
    var f = Estado(); f.tomada = ["womp": 1]; f.bateria = ["womp": 0]
    check(f.confere(Escrita(chave: "womp", tomada: 1, bateria: 0)) && !f.confere(Escrita(chave: "womp", tomada: 1, bateria: 1)), "confere por fonte")
    check(f.confere(Escrita(chave: "womp", tomada: nil, bateria: 0)), "nil = nao mexi")
    check(!Estado().leituraOk, "estado vazio nao e leitura ok")
}

print(falhas == 0 ? "\nTudo certo: nenhuma falha." : "\n\(falhas) falha(s).")
exit(falhas == 0 ? 0 : 1)
