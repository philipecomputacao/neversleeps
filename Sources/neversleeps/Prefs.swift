// Prefs.swift, SO preferencia do app. O estado do sistema nunca e guardado aqui.
import Foundation

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
}
