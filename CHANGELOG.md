# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versionado: SemVer una vez alcanzada v1.0; antes, solo se registran milestones.

## [Unreleased]

### M1 — Motor de audio (en curso)
- C++ `SineGenerator` (RT-safe, atómicos) en `ChipsEngineCxx`.
- C++ `DspLoadTracker` con EMA suavizado.
- C ABI extendida: `set_sine_frequency`, `set_sine_enabled`,
  `is_sine_enabled`, `dsp_load`, `sample_rate`.
- Swift facade `ChipsEngine` actualizada con accesores nuevos;
  marcada `@unchecked Sendable` (sincronización en C++).
- `ChipsAudioHost` implementado: `AVAudioEngine` + `AVAudioSession`
  (`.playback` con `mixWithOthers`), `AVAudioSourceNode` que
  delega en `engine.render`. Manejo de interrupciones y
  `.AVAudioEngineConfigurationChange`.
- Tests offline: `ChipsEngine` produce silencio cuando el seno está
  desactivado y RMS > 0.05 cuando está activo.
- App: pantalla principal con botón Play/Stop que toca un seno
  440 Hz. Status label muestra DSP load %, sample rate y buffer ms.

> Nota: la categoría `playAndRecord` del plan se difiere a un milestone
> posterior cuando se introduzca input MIDI/audio externo. M1 usa
> `.playback` para evitar prompt de permiso de micrófono innecesario.

### M0 — Fundamentos (en curso)
- Estructura de Swift Packages: `ChipsCore`, `ChipsEngine`, `ChipsAudioHost`, `ChipsMIDI`, `ChipsUIKit`, `ChipsModules`, `ChipsTesting`.
- App target inicial (UIKit) con pantalla "Chips".
- Configs de lint/format: SwiftLint strict, SwiftFormat, clang-format, EditorConfig.
- XcodeGen `project.yml` para reproducibilidad del proyecto Xcode.
- GitHub Actions CI: build, tests, lint en runner macOS.
- Fastlane scaffolding con lanes `test`, `beta`, `release`.
- Bundle ID `com.adriandomc.chips`. Plataforma iOS 17+, universal iPhone/iPad.
