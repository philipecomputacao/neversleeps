// Controlador+Teste.swift, o teste da tampa: a prova de que a trava funciona.
//
// Duas testemunhas independentes, e as duas precisam concordar:
//   1. o log do proprio macOS (`pmset -g log`): qualquer "Entering Sleep" a
//      partir do instante em que o teste comecou reprova;
//   2. o batimento do app a cada 5 s: se o Mac repousar, o batimento para e a
//      lacuna denuncia. Durante o teste o app declara atividade ao sistema,
//      senao o App Nap freia o timer com a tela apagada (no primeiro teste real
//      a pausa foi 19 s sem o Mac ter repousado).
import Cocoa
import NeversleepsCore

extension Controlador {

    @objc func iniciarTeste() {
        guard estado.trava == true else {
            Dialogos.alerta(t("Ligue a trava primeiro."), t("O teste confere se a trava funciona; sem ela ligada não há o que testar."))
            return
        }
        let (ok, _) = Dialogos.confirmar(
            t("Testar a tampa agora?"),
            t("1. Clique em Começar.\n2. Feche a tampa do Mac.\n3. Espere pelo menos 1 minuto (conte no celular).\n4. Abra a tampa.\n\nO resultado aparece sozinho na tela. Se o Mac tiver repousado, o app diz a hora e o motivo."),
            botao: t("Começar"), destrutivo: false)
        guard ok else { return }
        testeInicio = Date()
        testeUltimoBatimento = Date()
        testeMaiorLacuna = 0
        Prefs.testeUltimaFalha = nil
        testeAtividade = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated], reason: "neversleeps: teste da tampa em andamento")
        testeTimer?.invalidate()
        testeTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let agora = Date()
            self.testeMaiorLacuna = max(self.testeMaiorLacuna, agora.timeIntervalSince(self.testeUltimoBatimento))
            self.testeUltimoBatimento = agora
        }
    }

    @objc func testeEmAndamento() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = t("Teste em andamento")
        a.informativeText = t("Feche a tampa, espere 1 minuto e abra. O resultado aparece sozinho.\n\nSe você já abriu e nada apareceu, peça o resultado agora.")
        a.addButton(withTitle: t("Ver Resultado Agora"))
        a.addButton(withTitle: t("Continuar Esperando")).keyEquivalent = "\u{1b}"
        a.addButton(withTitle: t("Cancelar Teste"))
        switch a.runModal() {
        case .alertFirstButtonReturn: avaliarTeste()
        case .alertThirdButtonReturn: encerrarTeste()
        default: break
        }
    }

    func encerrarTeste() {
        testeTimer?.invalidate(); testeTimer = nil
        if let a = testeAtividade { ProcessInfo.processInfo.endActivity(a); testeAtividade = nil }
        testeInicio = nil
    }

    @objc func tampaAbriu() {
        guard testeInicio != nil else { return }
        // Da 2 s para o log do pmset assentar antes de ler.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.avaliarTeste() }
    }

    func avaliarTeste() {
        guard let inicio = testeInicio else { return }
        let duracao = Int(Date().timeIntervalSince(inicio))
        if duracao < 45 {
            // Abriu cedo demais: o teste continua valendo, so avisa.
            Dialogos.alerta(t("Muito rápido para provar."),
                            tf("O Mac ficou %d s fechado. Feche de novo e espere pelo menos 1 minuto. O teste continua.", duracao))
            return
        }
        // Congela a lacuna com o ultimo batimento antes de parar o timer.
        testeMaiorLacuna = max(testeMaiorLacuna, Date().timeIntervalSince(testeUltimoBatimento))
        encerrarTeste()

        let repousos = Sistema.repousosDesde(inicio)
        let lacuna = Int(testeMaiorLacuna)
        let parou = lacuna >= 30

        if repousos.isEmpty && !parou {
            Prefs.testeAprovadoEm = Date()
            Prefs.testeAprovadoDuracao = duracao
            Prefs.testeUltimaFalha = nil
            atualizarIcone()
            Dialogos.alerta(t("Aprovado: o Mac não repousou."),
                            tf("Ficou %d min %d s fechado.\n\n• O log do sistema não registrou nenhum repouso nesse intervalo.\n• O batimento interno do app não parou (maior pausa: %d s).\n\nPode fechar e guardar: o Mac continua trabalhando.",
                               duracao / 60, duracao % 60, lacuna))
        } else {
            var motivo = ""
            if let r = repousos.first { motivo = tf("O sistema registrou repouso às %@.", r.descricao) }
            if parou { motivo += (motivo.isEmpty ? "" : " ") + tf("O app ficou %d s sem conseguir rodar.", lacuna) }
            Prefs.testeAprovadoEm = nil
            Prefs.testeUltimaFalha = motivo
            Dialogos.alerta(t("Reprovado: o Mac repousou com a tampa fechada."),
                            motivo + "\n\n" + t("A trava está marcada como ligada, mas não segurou. Confira no Terminal:\npmset -g | grep -i sleepdisabled\n\nSe aparecer 0, desligue e ligue a trava de novo aqui e repita o teste."))
        }
    }
}
