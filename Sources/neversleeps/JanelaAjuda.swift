// =============================================================================
//  JanelaAjuda.swift, a janela "Ajuda do neversleeps"
//  LP Digital (@lpdigital.me), projetos/neversleeps
// =============================================================================
//
//  O QUE FAZ
//  ---------
//  Ajuda DENTRO do app, como manda o padrao: uma janela rolavel com o texto
//  formatado, selecionavel, na fonte do sistema. Antes, "Ajuda" abria o README
//  num editor de texto, atalho de desenvolvedor, nao ajuda de app.
//
//  COMO EDITAR O TEXTO
//  -------------------
//  Tudo esta em `conteudo()`: uma lista de blocos (titulo, secao, paragrafo,
//  passo). Acrescente ou troque blocos ali; a formatacao e aplicada por tipo.
//  O README.md do projeto continua sendo a documentacao completa para quem le
//  o repositorio; esta janela e o essencial para quem usa o app.
// =============================================================================

import Cocoa
import NeversleepsCore

final class JanelaAjuda: NSObject {

    private enum Bloco {
        case titulo(String)
        case secao(String)
        case paragrafo(String)
        case passo(Int, String, String)      // numero, titulo, explicacao
        case nota(String)
    }

    private let janela: NSWindow
    private let texto: NSTextView
    private var jaCentrou = false

    override init() {
        janela = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 600),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        let rolagem = NSTextView.scrollableTextView()
        texto = rolagem.documentView as! NSTextView
        super.init()

        janela.title = t("Ajuda do neversleeps")
        janela.isReleasedWhenClosed = false
        janela.minSize = NSSize(width: 440, height: 360)

        texto.isEditable = false
        texto.isSelectable = true
        texto.textContainerInset = NSSize(width: 24, height: 20)
        texto.backgroundColor = .textBackgroundColor
        texto.textStorage?.setAttributedString(render())

        janela.contentView = rolagem
    }

    func mostrar() {
        if !jaCentrou { janela.center(); jaCentrou = true }
        // App sem icone na Dock nao ganha o direito de ativar so com activate():
        // a janela abria ATRAS da janela da frente e parecia que nada tinha aberto.
        NSApp.activate(ignoringOtherApps: true)
        janela.orderFrontRegardless()
        janela.makeKeyAndOrderFront(nil)
    }

    // MARK: Conteudo

    private func conteudo() -> [Bloco] {
        let versao = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return [
            .titulo(t("neversleeps")),
            .paragrafo(t("Mantém o Mac trabalhando com a tampa fechada. Feito para deixar o Claude Code, ou qualquer terminal, terminando uma tarefa longa enquanto o MacBook vai na mochila.")),

            .secao(t("Para o Mac trabalhar fechado")),
            .passo(1, t("Ligue a trava"),
                   t("Clique na xícara na barra de menus e em “Impedir Repouso ao Fechar a Tampa”. O macOS pede Touch ID ou senha. A xícara fica cheia.")),
            .passo(2, t("Teste uma vez"),
                   t("Ligada não é a mesma coisa que provada. No menu, “Testar a Tampa…”: feche o Mac por 1 minuto e abra. O app lê o registro do sistema e diz se ele repousou. A linha da trava passa a mostrar “testada e aprovada”.")),
            .passo(3, t("Abra no início da sessão"),
                   t("Item do menu. Sem isso, depois de reiniciar não há ícone para desligar a trava, e o Mac fica sem repousar sem nenhum aviso.")),
            .passo(4, t("Deixe o iPhone entrar como internet"),
                   t("Ajustes do Sistema → Wi-Fi → Acesso Pessoal → Automaticamente. Quando o Wi-Fi conhecido sumir, o Mac entra no 3G/4G do iPhone sozinho, mesmo fechado. É um ajuste do Wi-Fi: o app não o controla.")),

            .secao(t("Lendo o ícone")),
            .paragrafo(t("Xícara vazia: repouso normal. Xícara cheia: trava ligada, o Mac não repousa ao fechar. Ampulheta: aguardando a sua autenticação. Triângulo: o app não conseguiu ler o estado de energia.")),

            .secao(t("O que a trava não resolve")),
            .paragrafo(t("Calor. Uma sessão do Claude Code é leve, o Mac passa o tempo esperando a rede. Compilação pesada ou testes em loop dentro de um bolso fechado não são. Nesses casos, mochila aberta.")),
            .paragrafo(t("Rede que cai por minutos. O Claude Code retenta quando a rede volta; uma queda longa pode derrubar a tarefa em andamento, e você retoma.")),

            .secao(t("Ajustes de Energia")),
            .paragrafo(t("O macOS guarda um conjunto de ajustes para a tomada e outro para a bateria. A janela “Ajustes de Energia…” (⌘,) mostra os dois lado a lado. Mude quantos quiser e clique “Aplicar…”: uma única autenticação para tudo. Depois, a janela relê o sistema e marca em vermelho o que o macOS recusou.")),
            .paragrafo(t("“Restaurar Padrões de Energia…” devolve tudo ao padrão de fábrica, inclusive a trava.")),

            .secao(t("Como o app sabe")),
            .paragrafo(t("Ele nunca guarda o estado do sistema: toda vez que o menu abre, pergunta ao macOS. Toda alteração é seguida de uma releitura, se o sistema aceitou o comando e ignorou o valor, você fica sabendo. Cancelar a autenticação não é erro: nada muda e o app fica em silêncio.")),

            .nota("neversleeps \(versao) · LP Digital (lpdigital.me) · MIT"),
        ]
    }

    // MARK: Formatacao

    private func render() -> NSAttributedString {
        let saida = NSMutableAttributedString()
        let corpo = NSFont.systemFont(ofSize: 13)
        let cor = NSColor.labelColor
        let secund = NSColor.secondaryLabelColor

        func par(_ espacoAntes: CGFloat, _ espacoDepois: CGFloat, recuo: CGFloat = 0) -> NSParagraphStyle {
            let p = NSMutableParagraphStyle()
            p.paragraphSpacingBefore = espacoAntes
            p.paragraphSpacing = espacoDepois
            p.lineSpacing = 2
            p.headIndent = recuo
            p.firstLineHeadIndent = recuo
            return p
        }

        for bloco in conteudo() {
            switch bloco {
            case .titulo(let t):
                saida.append(NSAttributedString(string: t + "\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 22, weight: .bold), .foregroundColor: cor,
                    .paragraphStyle: par(0, 6)]))
            case .secao(let t):
                saida.append(NSAttributedString(string: t + "\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: cor,
                    .paragraphStyle: par(18, 6)]))
            case .paragrafo(let t):
                saida.append(NSAttributedString(string: t + "\n", attributes: [
                    .font: corpo, .foregroundColor: cor, .paragraphStyle: par(0, 8)]))
            case .passo(let n, let t, let e):
                let linha = NSMutableAttributedString(string: "\(n). ", attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold), .foregroundColor: cor])
                linha.append(NSAttributedString(string: t + "\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: cor]))
                linha.addAttributes([.paragraphStyle: par(6, 2)], range: NSRange(location: 0, length: linha.length))
                saida.append(linha)
                saida.append(NSAttributedString(string: e + "\n", attributes: [
                    .font: corpo, .foregroundColor: cor, .paragraphStyle: par(0, 8, recuo: 22)]))
            case .nota(let t):
                saida.append(NSAttributedString(string: t + "\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 11), .foregroundColor: secund, .paragraphStyle: par(24, 0)]))
            }
        }
        return saida
    }
}
