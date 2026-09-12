// Dialogos.swift, alertas no idioma da Apple: botao com o nome do resultado
// ("Ligar", "Desligar", "Restaurar"), nunca "Continuar"; Esc no Cancelar.
import Cocoa
import NeversleepsCore

enum Dialogos {

    static func alerta(_ titulo: String, _ corpo: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = titulo
        a.informativeText = corpo
        a.alertStyle = .informational
        a.addButton(withTitle: t("OK"))
        a.runModal()
    }

    static func confirmar(_ titulo: String, _ corpo: String, botao: String,
                          destrutivo: Bool, comSupressao: Bool = false) -> (ok: Bool, suprimir: Bool) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = titulo
        a.informativeText = corpo
        a.alertStyle = destrutivo ? .warning : .informational
        a.addButton(withTitle: botao).hasDestructiveAction = destrutivo
        a.addButton(withTitle: t("Cancelar")).keyEquivalent = "\u{1b}"
        if comSupressao {
            a.showsSuppressionButton = true
            a.suppressionButton?.title = t("Não mostrar de novo")
        }
        let ok = a.runModal() == .alertFirstButtonReturn
        return (ok, comSupressao && a.suppressionButton?.state == .on)
    }

    /// Data relativa curta, no idioma do sistema ("hoje às 09:25").
    static func quando(_ d: Date) -> String {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
}
