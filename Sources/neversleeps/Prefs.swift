// Prefs.swift, SO preferencia do app. O estado do sistema nunca e guardado aqui.
// A excecao declarada e o HISTORICO da Falta de Energia (partida, ultimo sinal,
// periodo na bateria): e o que o app viu acontecer, para contar depois de um
// reinicio. Nunca e usado no lugar de uma leitura do sistema.
import Foundation
import NeversleepsCore

enum Prefs {
    private static let d = UserDefaults.standard

    static var avisoTampaVisto: Bool {
        get { d.bool(forKey: "avisoTampaVisto") }
        set { d.set(newValue, forKey: "avisoTampaVisto") }
    }
    static var jaAbriu: Bool {
        get { d.bool(forKey: "jaAbriu") }
        set { d.set(newValue, forKey: "jaAbriu") }
    }
    static var boasVindasVistas: Bool {
        get { d.bool(forKey: "boasVindasVistas") }
        set { d.set(newValue, forKey: "boasVindasVistas") }
    }
    /// "Nao avisar de novo" do alerta pos-repouso.
    static var avisoRepousoSilenciado: Bool {
        get { d.bool(forKey: "avisoRepousoSilenciado") }
        set { d.set(newValue, forKey: "avisoRepousoSilenciado") }
    }
    /// A pergunta "testar agora?" aparece UMA vez, na primeira vez que a trava liga.
    static var ofertaTesteVista: Bool {
        get { d.bool(forKey: "ofertaTesteVista") }
        set { d.set(newValue, forKey: "ofertaTesteVista") }
    }
    static var testeAprovadoEm: Date? {
        get { d.object(forKey: "testeAprovadoEm") as? Date }
        set { d.set(newValue, forKey: "testeAprovadoEm") }
    }
    static var testeAprovadoDuracao: Int {
        get { d.integer(forKey: "testeAprovadoDuracao") }
        set { d.set(newValue, forKey: "testeAprovadoDuracao") }
    }
    static var testeUltimaFalha: String? {
        get { d.string(forKey: "testeUltimaFalha") }
        set { d.set(newValue, forKey: "testeUltimaFalha") }
    }

    // MARK: Falta de Energia

    /// kern.boottime da partida em que o app rodou por ultimo.
    static var partidaConhecida: Double? {
        get { d.object(forKey: "partidaConhecida") as? Double }
        set { d.set(newValue, forKey: "partidaConhecida") }
    }
    /// kern.boottime da partida em que o app viu o proprio fim.
    static var encerradoNoBoot: Double? {
        get { d.object(forKey: "encerradoNoBoot") as? Double }
        set { d.set(newValue, forKey: "encerradoNoBoot") }
    }
    /// Batimento de 30 s: o ultimo instante em que o app sabe que o Mac estava ligado.
    static var ultimoSinal: Date? {
        get { d.object(forKey: "ultimoSinal") as? Date }
        set { d.set(newValue, forKey: "ultimoSinal") }
    }
    static var periodoNaBateria: PeriodoNaBateria? {
        get { d.data(forKey: "periodoNaBateria").flatMap { try? JSONDecoder().decode(PeriodoNaBateria.self, from: $0) } }
        set { d.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "periodoNaBateria") }
    }
    static var tarefas: [Tarefa] {
        get { d.data(forKey: "tarefas").flatMap { try? JSONDecoder().decode([Tarefa].self, from: $0) } ?? [] }
        set { d.set(try? JSONEncoder().encode(newValue), forKey: "tarefas") }
    }
    /// Ligado por padrao: cadastrar uma tarefa ja e o consentimento.
    static var retomarLigado: Bool {
        get { d.object(forKey: "retomarLigado") as? Bool ?? true }
        set { d.set(newValue, forKey: "retomarLigado") }
    }
    static var ultimoRelato: String? {
        get { d.string(forKey: "ultimoRelato") }
        set { d.set(newValue, forKey: "ultimoRelato") }
    }
    static var ultimoRelatoEm: Date? {
        get { d.object(forKey: "ultimoRelatoEm") as? Date }
        set { d.set(newValue, forKey: "ultimoRelatoEm") }
    }
}
