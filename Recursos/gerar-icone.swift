// =============================================================================
//  gerar-icone.swift — desenha o icone do neversleeps
//  LP Digital (@lpdigital.me)
// =============================================================================
//
//  O QUE FAZ
//  ---------
//  Gera `icone-1024.png`, a arte base do icone do app. O `construir.sh` usa esse
//  PNG, reduz nos tamanhos do sistema com `sips` e monta o `.icns` com `iconutil`.
//
//  COMO RODAR SOZINHO
//  ------------------
//  swift Recursos/gerar-icone.swift          (grava icone-1024.png na pasta atual)
//
//  DECISOES DE DESENHO (por que esta assim)
//  ----------------------------------------
//  1. A forma e uma SUPERELIPSE, nao um retangulo de cantos arredondados. Essa e a
//     diferenca real entre um icone que parece do macOS e um que parece colado.
//     A curvatura e continua: nao ha ponto onde a reta vira arco.
//  2. A arte ocupa 824 de 1024 px, que e a grade que a Apple usa para apps de
//     macOS. As margens existem para o icone respirar no Dock e no Finder.
//  3. O glifo e um SF Symbol de verdade (`cup.and.saucer.fill`), o mesmo que
//     aparece na barra de menus quando a trava esta ativa. Icone e barra falam a
//     mesma lingua. Peso bold: a 16 px, tracos finos somem e sobra um borrao.
//  4. Paleta do sistema: grafite (#2C2C2E -> #0A0A0C) com o amarelo da Apple
//     (#FFD60A). Nenhuma cor inventada.
//
//  GOTCHA
//  ------
//  Roda como script (`swift arquivo.swift`), nao precisa compilar. Se um dia o
//  simbolo `cup.and.saucer.fill` sumir de uma versao do macOS, o script avisa e
//  para, em vez de gravar um PNG vazio. O mesmo vale se o contexto grafico nao
//  puder ser criado: erro na tela, nunca PNG transparente em silencio.
//
// =============================================================================

import Cocoa

let lado: CGFloat = 1024
let margem: CGFloat = 100          // 1024 - 2*100 = 824, a grade da Apple

/// Superelipse (squircle). n maior = ombro mais "quadrado", que e o jeito Apple.
func squircle(in r: NSRect, n: Double = 5.0) -> NSBezierPath {
    let p = NSBezierPath()
    let a = Double(r.width / 2), b = Double(r.height / 2)
    let cx = Double(r.midX), cy = Double(r.midY)
    let passos = 720
    for i in 0...passos {
        let t = 2.0 * Double.pi * Double(i) / Double(passos)
        let ct = cos(t), st = sin(t)
        let x = cx + a * (ct < 0 ? -1 : 1) * pow(abs(ct), 2.0 / n)
        let y = cy + b * (st < 0 ? -1 : 1) * pow(abs(st), 2.0 / n)
        if i == 0 { p.move(to: NSPoint(x: x, y: y)) } else { p.line(to: NSPoint(x: x, y: y)) }
    }
    p.close()
    return p
}

/// Pinta um SF Symbol de uma cor so, preservando a forma.
/// Usa lockFocus() de proposito: aqui o fator de escala nao importa, porque o
/// resultado e redesenhado dentro do bitmap de tamanho fixo mais abaixo.
func tingir(_ img: NSImage, _ cor: NSColor) -> NSImage {
    let out = NSImage(size: img.size)
    out.lockFocus()
    cor.set()
    NSRect(origin: .zero, size: img.size).fill()
    img.draw(in: NSRect(origin: .zero, size: img.size),
             from: .zero, operation: .destinationIn, fraction: 1.0)
    out.unlockFocus()
    return out
}

guard let simbolo = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "neversleeps")?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 470, weight: .bold)) else {
    FileHandle.standardError.write("ERRO: o simbolo cup.and.saucer.fill nao existe nesta versao do macOS.\n".data(using: .utf8)!)
    exit(1)
}

// Bitmap com tamanho EXATO em pixels. Usar lockFocus() numa NSImage herdaria o
// fator Retina da tela e gravaria 2048 num monitor e 1024 noutro — o icone nao
// pode depender de qual monitor estava ligado na hora de gerar.
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                 pixelsWide: Int(lado), pixelsHigh: Int(lado),
                                 bitsPerSample: 8, samplesPerPixel: 4,
                                 hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .calibratedRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0) else {
    FileHandle.standardError.write("ERRO: nao consegui criar o bitmap.\n".data(using: .utf8)!)
    exit(1)
}
rep.size = NSSize(width: lado, height: lado)

guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    FileHandle.standardError.write("ERRO: nao consegui criar o contexto grafico.\n".data(using: .utf8)!)
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

// Fundo: grafite do sistema, claro em cima e escuro embaixo, como os icones nativos.
let corpo = NSRect(x: margem, y: margem, width: lado - 2 * margem, height: lado - 2 * margem)
let forma = squircle(in: corpo)
let gradiente = NSGradient(starting: NSColor(srgbRed: 0.173, green: 0.173, blue: 0.180, alpha: 1),
                           ending:   NSColor(srgbRed: 0.039, green: 0.039, blue: 0.047, alpha: 1))
gradiente?.draw(in: forma, angle: -90)

// Fio de luz na borda superior: e o que da volume sem precisar de sombra falsa.
NSColor(white: 1.0, alpha: 0.14).setStroke()
forma.lineWidth = 3
forma.stroke()

// Glifo centrado, no amarelo do sistema.
let amarelo = NSColor(srgbRed: 1.0, green: 0.839, blue: 0.039, alpha: 1.0)
let glifo = tingir(simbolo, amarelo)
let g = glifo.size
glifo.draw(in: NSRect(x: (lado - g.width) / 2, y: (lado - g.height) / 2,
                      width: g.width, height: g.height),
           from: .zero, operation: .sourceOver, fraction: 1.0)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("ERRO: nao consegui gerar o PNG.\n".data(using: .utf8)!)
    exit(1)
}

let destino = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("icone-1024.png")
do {
    try png.write(to: destino)
    print("Gravado: \(destino.path)")
} catch {
    FileHandle.standardError.write("ERRO: nao consegui gravar \(destino.path): \(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
