# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versionado: SemVer una vez alcanzada v1.0; antes, solo se registran milestones.

## [Unreleased]

### M0 — Fundamentos (en curso)
- Estructura de Swift Packages: `ChipsCore`, `ChipsEngine`, `ChipsAudioHost`, `ChipsMIDI`, `ChipsUIKit`, `ChipsModules`, `ChipsTesting`.
- App target inicial (UIKit) con pantalla "Chips".
- Configs de lint/format: SwiftLint strict, SwiftFormat, clang-format, EditorConfig.
- XcodeGen `project.yml` para reproducibilidad del proyecto Xcode.
- GitHub Actions CI: build, tests, lint en runner macOS.
- Fastlane scaffolding con lanes `test`, `beta`, `release`.
- Bundle ID `com.adriandomc.chips`. Plataforma iOS 17+, universal iPhone/iPad.
