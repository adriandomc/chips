# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versionado: SemVer una vez alcanzada v1.0; antes, solo se registran milestones.

## [Unreleased]

### M3 — Framework UI custom (en curso)
- `ChipsTheme` con paleta del mockup: top bar lavender, sidebar gris,
  paleta pastel de pistas (10 colores), accent cyan, transport green/red,
  fuentes mono y sans.
- Componentes base custom (UIKit puro, sin SwiftUI):
  `ChipsControl` (base), `ChipsButton` (rectángulo con esquinas duras),
  `ChipsIconButton` (icon-only para sidebar), `ChipsKnob` (drag vertical
  con anillo cyan e indicador), `ChipsFader` (vertical), `ChipsTextField`,
  `ChipsTimecodeLabel`, `ChipsTransportButton` (play/stop dibujados),
  `ChipsPianoKeyboard` (multi-touch, blancas y negras).
- App shell: `AppShellViewController` con top bar (timecode + transport),
  sidebar derecha (6 iconos: sequencer, mixer, synthesizer, grid,
  settings, help), área de contenido. Navegación por replace child VC.
- Secciones implementadas:
  - **Sequencer**: 6 track rows con colores pastel y label "Track N".
  - **Mixer**: 10 channel strips horizontales con EQ box, sends, fader,
    pan knob, mute/solo (scroll horizontal).
  - **Synthesizer**: panel gris con dos filas de knobs (envelope ADSR +
    oscilador FINETUNE/TUNE/VOLUME/WAVE/SUB OSC/GLIDE) + teclado piano
    al final. Volumen y notas conectadas al sine generator del engine.
  - **Grid**: placeholder (M5).
  - **Settings**: form con NEW/SAVE/LOAD, Project Name, Author, Tempo +
    TAP TEMPO, Export con File Format, MASTER TRACK / STEMS.
  - **Help**: títulos + lista de versiones de paquetes.
- `AudioCoordinator` MainActor-aislado: dueño del `ChipsAudioHost`,
  expone API simple para start/stop, set frequency/amplitude/enabled
  del sine. Helper `frequency(forMidi:)` para conversión MIDI → Hz.
- `SceneDelegate` instancia el coordinator y monta el shell.
  `RootViewController.swift` eliminado.

### M2 — Sistema modular (en curso)
- C++ `IModule` interface (prepare/reset/process/handleParameterChange + I/O spec).
- `ProcessContext` con audio I/O, frames, sampleRate, tickPosition, tempo.
- `BufferPool` pre-alocado por Plan (evita UAF si compile() corre durante render).
- `SpscQueue<T, Capacity>` lock-free single-producer/single-consumer (cache-aligned).
- `Graph`: addNode / removeNode / connect / disconnect / setOutputNode / compile / render.
  - Topological sort vía Kahn's algorithm (detecta ciclos).
  - Cada compile() construye un nuevo Plan con su propio BufferPool y se publica
    al audio thread vía atomic pointer swap (release-acquire).
  - Plans viejos quedan retenidos en `retainedPlans_` (M2 leak controlado;
    GC con epoch reclamation queda para M2.5/M3).
- Refactor de `SineGenerator` para implementar `IModule` (params: frequency,
  enabled, amplitude). Atómicos relaxed se mantienen para acceso desde control
  thread fuera del SPSC.
- Nuevos módulos `PassthroughModule` (1+ canal) y `TestSourceModule` (ramp
  determinística), usados por tests offline.
- C ABI nueva: `chips_engine_add_node`, `remove_node`, `connect`, `disconnect`,
  `set_output_node`, `compile`, `set_parameter`. Constants `CHIPS_NODE_TYPE_*`.
  Eliminados los `chips_engine_set_sine_*` legacy de M1.
- Swift facade actualizada con `ChipsNodeType` enum y métodos del grafo. Helper
  `setParameter(_:sine:value:)` para usar `SineParam` tipado.
- Tests offline: silencio sin grafo, sine -> output, compile sin output node
  falla, ciclo detectado, 50 passthroughs en cadena producen RMS idéntico al
  source directo, removeNode + recompile.
- App: `RootViewController` actualizado para construir el grafo (sine -> output,
  compile) antes de start.

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
