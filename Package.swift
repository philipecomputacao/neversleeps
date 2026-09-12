// swift-tools-version:5.9
// neversleeps — Package.swift
// `swift build -c release` compila; `swift test` roda os testes do nucleo.
// O bundle .app e montado por construir.sh a partir do binario gerado aqui.
import PackageDescription

let package = Package(
    name: "neversleeps",
    defaultLocalization: "pt-BR",
    platforms: [.macOS(.v14)],
    targets: [
        // Nucleo sem AppKit: modelo, parser do pmset, leitura do sistema. Testavel.
        .target(name: "NeversleepsCore", path: "Sources/NeversleepsCore"),
        // O app: menu, janelas, privilegio, teste da tampa.
        .executableTarget(name: "neversleeps", dependencies: ["NeversleepsCore"],
                          path: "Sources/neversleeps"),
        // Portao local sem framework de teste (XCTest/Testing exigem Xcode).
        .executableTarget(name: "verificar", dependencies: ["NeversleepsCore"],
                          path: "Sources/verificar"),
        // Testes de verdade (Swift Testing) — rodam no CI, que tem Xcode.
        .testTarget(name: "NeversleepsCoreTests", dependencies: ["NeversleepsCore"],
                    path: "Tests/NeversleepsCoreTests"),
    ]
)
