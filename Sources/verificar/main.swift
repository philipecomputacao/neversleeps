// verificar, as checagens do nucleo SEM framework de teste, para rodar em
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

print("Falta de energia")
do {
    check(Parser.carga(Amostras.battBateria) == 78 && Parser.carga(Amostras.battTomada) == 83, "carga da bateria")
    check(Parser.carga(Amostras.battSemBateria) == nil, "Mac sem bateria = nao sei")
    check(Parser.bootPreference(Amostras.nvramSoCarregador) == 1 && Parser.bootPreference(Amostras.nvramNenhum) == 0, "BootPreference %01 e %00")
    check(Parser.bootPreference(Amostras.nvramAusente) == nil, "erro do nvram nao vira valor")
    check(Parser.fileVault(Amostras.fileVaultLigado) == true && Parser.fileVault(Amostras.fileVaultDesligado) == false, "FileVault")
    check(Parser.fileVault("") == nil, "FileVault sem saida = nao sei")

    check(PartidaAutomatica(byte: nil) == .padrao && PartidaAutomatica.padrao.byte == nil, "ausente = padrao, liga nos dois")
    check(PartidaAutomatica(byte: 0x01) == PartidaAutomatica(aoConectarCarregador: true, aoAbrirTampa: false), "%01 impede so a tampa (Apple 120622)")
    check(PartidaAutomatica(byte: 0x02) == PartidaAutomatica(aoConectarCarregador: false, aoAbrirTampa: true), "%02 impede so o carregador")
    check(PartidaAutomatica(byte: 0x07) == nil, "valor nao documentado nao e adivinhado")
    check(PartidaAutomatica.padrao.comando == "/usr/sbin/nvram -d BootPreference", "padrao apaga a variavel")
    check(PartidaAutomatica(aoConectarCarregador: false, aoAbrirTampa: false).comando == "/usr/sbin/nvram BootPreference=%00", "comando %00")
    let ida = [0x00, 0x01, 0x02].allSatisfy { PartidaAutomatica(byte: UInt8($0))?.byte == UInt8($0) }
    check(ida, "byte vai e volta")

    check(Reinicio.avaliar(bootAtual: 100, bootConhecido: nil, encerradoNoBoot: nil) == .primeiraVez, "sem registro = primeira vez")
    check(Reinicio.avaliar(bootAtual: 100.4, bootConhecido: 100, encerradoNoBoot: nil) == .mesmaPartida, "mesmo boottime = so reabriu o app")
    check(Reinicio.avaliar(bootAtual: 500, bootConhecido: 100, encerradoNoBoot: 100) == .encerradoNormal, "app viu o proprio fim = normal")
    check(Reinicio.avaliar(bootAtual: 500, bootConhecido: 100, encerradoNoBoot: 50) == .inesperado, "fim visto em outra partida nao vale")
    check(Reinicio.avaliar(bootAtual: 500, bootConhecido: 100, encerradoNoBoot: nil) == .inesperado, "sem fim visto = inesperado")

    var p = PeriodoNaBateria(inicio: Date(), bateriaInicio: 80)
    check(Relato.causa(nil) == .desconhecida, "na tomada = causa desconhecida")
    check(Relato.causa(p) == .estavaNaBateria, "na bateria com carga alta")
    p.ultimaBateria = 3
    check(Relato.causa(p) == .bateriaAcabou, "na bateria com 3% = a bateria acabou")
    p.fim = Date()
    check(Relato.causa(p) == .desconhecida, "periodo encerrado nao explica o reinicio")

    let tarefa = Tarefa(pasta: "~/Projetos/it's", comando: "claude --continue")
    let s = tarefa.script(casa: "/Users/x")
    check(s.contains("cd '/Users/x/Projetos/it'\\''s' ||"), "til expandido e aspa simples escapada")
    check(s.contains("\nclaude --continue\n"), "comando em linha propria")
    check(s.hasPrefix("#!/bin/zsh -l\n"), "shell de login: PATH do usuario")
    check(!Tarefa(pasta: " ", comando: "x").valida && Tarefa(pasta: "~", comando: "x").valida, "tarefa valida")
}

print("Historico")
do {
    let base = data("2026-09-28 10:00:00 -0300")
    func em(_ min: Double) -> Date { base.addingTimeInterval(min * 60) }
    func ev(_ tipo: TipoEvento, _ min: Double, _ ajuste: (inout Evento) -> Void = { _ in }) -> Evento {
        var e = Evento(tipo, quando: em(min)); ajuste(&e); return e
    }
    check(Parser.tampaFechada(Amostras.ioregTampaAberta) == false, "tampa aberta no ioreg")
    check(Parser.tampaFechada(Amostras.ioregTampaAberta.replacingOccurrences(of: "State\" = No", with: "State\" = Yes")) == true, "tampa fechada no ioreg")
    check(Parser.tampaFechada("") == nil, "sem ioreg = nao sei")
    check(Evento.duracao(45) == "45 s" && Evento.duracao(720) == "12 min" && Evento.duracao(72) == "1 min 12 s" && Evento.duracao(8040) == "2 h 14 min" && Evento.duracao(7200) == "2 h", "duracao legivel")
    check(ev(.repousou, 0) { $0.porTampa = true; $0.trava = false }.descricao == "A trava estava desligada", "repouso pela tampa com a trava desligada e dito")
    check(ev(.voltouATomada, 0) { $0.duracao = 3000; $0.cargaInicial = 90; $0.carga = 71 }.descricao == "50 min na bateria · 90% → 71%", "volta para a tomada com duracao e carga")
    check(ev(.ajustesAplicados, 0) { $0.chaves = ["powernap", "naoexiste"] }.descricao == "Power Nap", "ajustes guardam chaves e traduzem na hora")
    check(ev(.retomada, 0) { $0.abertas = 2; $0.total = 2 }.selo == "2 tarefas reabertas no Terminal"
          && ev(.retomada, 0) { $0.abertas = 1; $0.total = 2 }.selo == "1 de 2 abertas" && ev(.retomada, 0).selo == nil, "selo da retomada")
    check(ev(.travaLigada, 0) { $0.origem = .fora }.categoria == .trava && ev(.retomada, 0).categoria == .reinicios, "categorias")

    let fim = em(600)
    check(Fita.segmentos([], de: base, ate: fim, fonteAgora: .tomada) == [Segmento(base, fim, .desconhecido)], "sem diario = desconhecido, nunca palpite")
    let dia = [ev(.appAbriu, 0), ev(.saiuDaTomada, 60), ev(.repousou, 90), ev(.despertou, 120), ev(.voltouATomada, 180)]
    let f = Fita.segmentos(dia, de: base, ate: fim, fonteAgora: .tomada)
    check(f.map { $0.faixa } == [.tomada, .bateria, .repouso, .bateria, .tomada], "tomada, bateria, repouso, bateria, tomada")
    check(f.first?.inicio == base && f.last?.fim == fim, "a fita cobre a janela inteira")
    let g = Fita.segmentos([ev(.saiuDaTomada, 100)], de: em(50), ate: fim, fonteAgora: .bateria)
    check(g.map { $0.faixa } == [.desconhecido, .bateria], "antes do primeiro evento = desconhecido")
    let queda = [ev(.appAbriu, 0), ev(.saiuDaTomada, 10), ev(.reinicioInesperado, 300) { $0.inicio = em(200); $0.fonte = .tomada }]
    let h = Fita.segmentos(queda, de: base, ate: fim, fonteAgora: .tomada)
    check(h.map { $0.faixa } == [.tomada, .bateria, .desligado, .tomada], "reinicio inesperado: desligado do ultimo sinal ate a partida")
    check(h[2].inicio == em(200) && h[2].fim == em(300), "o desligado comeca no ultimo sinal")
    let antes = Fita.segmentos([ev(.saiuDaTomada, -30), ev(.appAbriu, 20)], de: base, ate: fim, fonteAgora: .tomada)
    check(antes.map { $0.faixa } == [.bateria], "estado anterior a janela vale no inicio")

    check(Diario.podar([ev(.appAbriu, -60 * 24 * 31), ev(.appAbriu, 0)], agora: base).count == 1, "poda o que passou de 30 dias")
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("ns-verificar-\(getpid()).jsonl")
    let d = Diario(url: url)
    d.acrescentar(ev(.saiuDaTomada, 1) { $0.carga = 80 })
    d.acrescentar(ev(.appAbriu, 0))
    if let h = try? FileHandle(forWritingTo: url) { _ = try? h.seekToEnd(); try? h.write(contentsOf: Data("{lixo}\n".utf8)); try? h.close() }
    let lidos = d.ler()
    check(lidos.count == 2 && lidos.first?.tipo == .appAbriu && lidos.last?.carga == 80, "diario grava, ignora linha ruim e ordena")
    check(Diario.repousoRecente([ev(.repousou, 0) { $0.porTampa = true }], agora: em(10), minutos: 15)?.porTampa == true, "repouso recente achado")
    check(Diario.repousoRecente([ev(.repousou, 0)], agora: em(20), minutos: 15) == nil, "repouso antigo ignorado")
    d.apagar()
    check(d.ler().isEmpty, "apagar zera o historico")
}

print(falhas == 0 ? "\nTudo certo: nenhuma falha." : "\n\(falhas) falha(s).")
exit(falhas == 0 ? 0 : 1)
