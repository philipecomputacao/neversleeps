// EnergiaTests.swift, o modulo Falta de Energia. Mesmo conjunto do alvo
// `verificar`, em Swift Testing (roda no CI, que tem Xcode).
import Testing
import Foundation
@testable import NeversleepsCore

@Suite struct EnergiaTests {

    @Test func cargaDaBateria() {
        #expect(Parser.carga(Amostras.battBateria) == 78)
        #expect(Parser.carga(Amostras.battTomada) == 83)
        #expect(Parser.carga(Amostras.battSemBateria) == nil, "Mac sem bateria")
    }

    @Test func bootPreference() {
        #expect(Parser.bootPreference(Amostras.nvramSoCarregador) == 1)
        #expect(Parser.bootPreference(Amostras.nvramNenhum) == 0)
        #expect(Parser.bootPreference(Amostras.nvramAusente) == nil, "mensagem de erro nao vira valor")
    }

    @Test func fileVault() {
        #expect(Parser.fileVault(Amostras.fileVaultLigado) == true)
        #expect(Parser.fileVault(Amostras.fileVaultDesligado) == false)
        #expect(Parser.fileVault("") == nil)
    }

    /// Valores da Apple (suporte 120622): %00 impede os dois, %01 so a tampa,
    /// %02 so o carregador, ausente = padrao.
    @Test func partidaAutomaticaSegueAApple() {
        #expect(PartidaAutomatica(byte: nil) == .padrao)
        #expect(PartidaAutomatica(byte: 0x00) == PartidaAutomatica(aoConectarCarregador: false, aoAbrirTampa: false))
        #expect(PartidaAutomatica(byte: 0x01) == PartidaAutomatica(aoConectarCarregador: true, aoAbrirTampa: false))
        #expect(PartidaAutomatica(byte: 0x02) == PartidaAutomatica(aoConectarCarregador: false, aoAbrirTampa: true))
        #expect(PartidaAutomatica(byte: 0x07) == nil, "valor nao documentado")
        for b: UInt8 in [0, 1, 2] { #expect(PartidaAutomatica(byte: b)?.byte == b) }
    }

    @Test func comandoDaPartida() {
        #expect(PartidaAutomatica.padrao.comando == "/usr/sbin/nvram -d BootPreference")
        #expect(PartidaAutomatica(aoConectarCarregador: false, aoAbrirTampa: true).comando == "/usr/sbin/nvram BootPreference=%02")
    }

    @Test func reinicio() {
        #expect(Reinicio.avaliar(bootAtual: 100, bootConhecido: nil, encerradoNoBoot: nil) == .primeiraVez)
        #expect(Reinicio.avaliar(bootAtual: 100.4, bootConhecido: 100, encerradoNoBoot: nil) == .mesmaPartida)
        #expect(Reinicio.avaliar(bootAtual: 500, bootConhecido: 100, encerradoNoBoot: 100) == .encerradoNormal)
        #expect(Reinicio.avaliar(bootAtual: 500, bootConhecido: 100, encerradoNoBoot: 50) == .inesperado,
                "fim visto em outra partida nao vale")
        #expect(Reinicio.avaliar(bootAtual: 500, bootConhecido: 100, encerradoNoBoot: nil) == .inesperado)
    }

    @Test func causaProvavel() {
        var p = PeriodoNaBateria(inicio: Date(), bateriaInicio: 80)
        #expect(Relato.causa(nil) == .desconhecida)
        #expect(Relato.causa(p) == .estavaNaBateria)
        p.ultimaBateria = 3
        #expect(Relato.causa(p) == .bateriaAcabou)
        p.fim = Date()
        #expect(Relato.causa(p) == .desconhecida, "periodo encerrado nao explica o reinicio")
    }

    @Test func scriptDaTarefa() {
        let s = Tarefa(pasta: "~/Projetos/it's", comando: "claude --continue").script(casa: "/Users/x")
        #expect(s.hasPrefix("#!/bin/zsh -l\n"))
        #expect(s.contains("cd '/Users/x/Projetos/it'\\''s' ||"))
        #expect(s.contains("\nclaude --continue\n"))
        #expect(!Tarefa(pasta: " ", comando: "x").valida)
    }
}
