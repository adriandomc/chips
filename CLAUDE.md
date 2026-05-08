# CLAUDE.md — Guía para agentes y desarrolladores trabajando en Chips

> Este documento es la fuente de verdad arquitectónica del proyecto.
> Léelo antes de hacer cambios no triviales.

## 1. Qué es Chips

DAW modular para iOS/iPadOS. Inspiración: Caustic 3. Diferencial: **arquitectura sin restricciones de slots** (cualquier número de instrumentos y efectos limitados solo por CPU).

UI **completamente custom** — sin Liquid Glass, sin componentes nativos visualmente. Los diseños vienen del usuario en Figma; no se inventan componentes sin diseño.

Plataforma mínima: iOS 17. Lenguajes: Swift 6 (control plane) + C++17 (DSP). Buffers RT-safe, audio en `AVAudioEngine` con `AVAudioSourceNode` que delega en el grafo C++.

## 2. Principio rector: modularidad plug-and-play

**Definición operativa**: añadir un nuevo instrumento (ej. un drum sampler) o un nuevo efecto (ej. un compressor) debe ser un cambio **localizado**. No debe requerir editar:
- El coordinator central de la app.
- El `ProjectSnapshot` (formato de proyecto guardado).
- La UI core (top bar, sidebar, navegación).
- Los archivos centrales del engine (`makeModuleFromTypeId`).

Lo que sí es aceptable editar al añadir un módulo:
- Crear `XxxModule.hpp/.cpp` (su DSP).
- Crear su `ViewController` (su UI propia).
- Registrarlo una vez en un punto de entrada (registry).

Si añadir un módulo te obliga a tocar más de eso, **estás violando la ideología**. Detén el cambio y refactoriza el sistema antes.

## 3. Arquitectura por capas

```
┌──────────────────────────────────────────────────────────┐
│ App (UIKit, Chips/)                                      │
│ AppShell · Sections · AudioCoordinator                   │
└────────┬─────────────────────────────────────────────────┘
         │ Swift API
┌────────▼─────────────────────────────────────────────────┐
│ ChipsAudioHost (Swift, MainActor)                        │
│ AVAudioEngine · AVAudioSession · AVAudioSourceNode       │
└────────┬─────────────────────────────────────────────────┘
         │ Swift facade
┌────────▼─────────────────────────────────────────────────┐
│ ChipsEngine (Swift facade)                               │
│ ChipsEngine class (OpaquePointer handle)                 │
└────────┬─────────────────────────────────────────────────┘
         │ C ABI
┌────────▼─────────────────────────────────────────────────┐
│ ChipsEngineCxx (C++ DSP)                                 │
│ Graph · IModule · BufferPool · SpscQueue                 │
│ Modules: AdditiveSynth, Mixer, Delay, Reverb, ...        │
└──────────────────────────────────────────────────────────┘

Apoyo:
ChipsCore   (Swift) · Project, Pattern, Track, TransportState, SequencerEngine, WavWriter
ChipsUIKit  (Swift) · Theme, ChipsButton, ChipsKnob, ChipsFader, ChipsPianoKeyboard, ...
ChipsMIDI   (Swift) · CoreMIDI wrapper (skeleton)
```

**Threading**:
- **Audio thread** (RT): solo llama `Graph::render` (que llama `IModule::process` y drena el SPSC). Sin alloc, sin locks, sin Obj-C/Swift.
- **Control thread (MainActor)**: addNode/connect/compile, set parameters, send notes.
- **Comunicación control → audio**: SPSC queue (`ParameterEvent` con kind Param/NoteOn/NoteOff).
- **Comunicación audio → control**: ninguna por ahora (métricas via atomics).

## 4. Cómo añadir un nuevo instrumento (estado *deseado*, ver §7)

> En el estado actual del código, esta lista es más larga (ver §7). El refactor
> "modular foundation" pone esto en su mínima expresión.

1. Crear `Packages/ChipsEngine/Sources/ChipsEngineCxx/src/MyInstrument.hpp/.cpp`.
   - Implementar `chips::IModule`.
   - Declarar paramIds en un enum interno.
   - **RT-safety**: en `process()` no allocar, no bloquear, no usar excepciones.
2. Auto-registrarse en el `ModuleRegistry` (estático en `MyInstrument.cpp`):
   ```cpp
   namespace { const auto _ = chips::ModuleRegistry::instance().register_(
       "my_instrument", [] { return std::make_unique<MyInstrument>(); });
   }
   ```
3. Opcional: si tiene UI propia y custom controls, crear
   `Chips/Sections/Instruments/MyInstrumentPanelViewController.swift`
   y registrarlo en el catálogo de UI (`InstrumentUIRegistry`).
4. Añadir tests offline en `ChipsEngineTests`.

No editar ningún otro archivo.

## 5. Cómo añadir un nuevo efecto

Igual que un instrumento, pero `numAudioInputs() = 2` (stereo in) y sin `handleNoteOn/Off`.
Auto-registro en el mismo `ModuleRegistry`.

## 6. Cómo añadir un nuevo canal de mixer / track del sequencer

Tracks: `SequencerEngine.setTracks([Track])`. Cada `Track` declara su `instrumentNodeId` (estado deseado). El `AudioCoordinator` enruta `noteOn/Off` al `instrumentNodeId` del track que disparó.

Mixer: `MixerModule` debe construirse paramétricamente (`MixerModule(numChannels: Int)`); en estado deseado los proyectos serializan su número de canales.

## 7. Estado actual y deuda técnica

> El plan de refactor descrito en `docs/architecture-refactor.md` está
> **ejecutado** (R1–R4 mergeados). La capa Swift y la capa C++ comparten
> ahora la misma ideología modular plug-and-play.

**Lo que cumple**:
- `Graph` (C++) admite topologías arbitrarias en runtime.
- `IModule` es genérico, con metadata (`ParamSpec` + `typeId`) accesible vía C ABI.
- `ModuleRegistry` self-registering: cada módulo se registra en su propio `.cpp`. `makeModuleFromTypeId` es un wrapper sobre el registry.
- `ProjectGraph` (Swift) almacena nodos + conexiones + tracks dinámicamente, con `NodeRef = UUID` estables. `ProjectMigrator.migrateV1ToV2` migra proyectos antiguos transparentemente.
- `ProjectController` (reemplaza `AudioCoordinator`) consume `ProjectGraph` como single source of truth y reconstruye el motor desde él.
- `Track.instrumentRef` rutea cada nota del sequencer al instrumento correcto.
- `MixerModule` paramétrico (`numChannels` en runtime, default 8, max 64).
- `InstrumentUIRegistry` con builders por typeId; fallback a UI genérica generada desde `ParamSpec`.
- Mixer expone meters dinámicos (peak por canal + master) vía atomics.
- Dispatch de `ParameterEvent` indexado por `nodeId` con `frameOffset` para scheduling sample-accurate intra-buffer.
- WAV export offline (faster-than-realtime) + stems por track.
- CoreMIDI input real (`ChipsMIDIInput` con virtual destination "Chips").
- Catálogo: 4 instrumentos (additive, subtractive, FM, wavetable, beatbox) y 7 efectos (mixer, delay, reverb, compressor, eq, chorus, distortion, filter).

**Limitaciones de scope (diferimientos)**:
- `SequencerEngine` Swift corre en MainActor con timer 500 Hz (jitter inter-buffer ~2 ms). El `frameOffset` está disponible para que un futuro driver del sequencer en C++ logre sample-accuracy intra-buffer también desde el sequencer (no solo desde live MIDI).
- `CommandBus` (`ChipsCore`) tiene la infraestructura de undo/redo pero las acciones de la UI todavía no están envueltas en `Command`s.
- AUv3 host / instrument hosting fuera de scope.
- Privacy Policy URL, Terms URL y App Store assets son placeholders hasta que el usuario complete el enrollment de Apple Developer.

## 8. Convenciones del repo

- **Lint**: SwiftLint strict + SwiftFormat + clang-format. Configs en raíz. CI los corre y postea diffs como comentarios al PR.
- **CI**: GitHub Actions, runner `macos-15`. Lint primero; si verde, build/test sobre simulador iPhone descubierto dinámicamente.
- **Build**: XcodeGen (`project.yml`). El `.xcodeproj` no se commitea. Local: `xcodegen generate`.
- **Branches**: cada milestone en `feat/m<N>-<slug>`. PR a `main` con merge commit (no squash) — ver historia.
- **Commits**: descriptivos, multi-line con qué/por qué. No referencias a tickets externos.
- **Tests**: `XCTest`. C++ accedido vía Swift facade; tests de DSP son determinísticos (RMS, golden hash).
- **No SwiftUI** en superficies de producto. Sí permitido: SF Symbols como glyphs en sidebar (no es chrome del sistema).
- **No JUCE** ni dependencias GPL. Solo MIT/BSD/Apache. Ver `THIRD_PARTY_LICENSES.md`.

## 9. Antipatrones a evitar

- ❌ Añadir un nuevo `Param` enum específico a `ChipsEngine.swift` y un `setParameter(_:thatModule:value:)` overload por cada módulo. Eso escala mal. Prefiere `setParameter(nodeId, paramId, value)` genérico (ya existe).
- ❌ Hardcodear node IDs como `let` en el coordinator. Usa una colección dinámica indexada por algún identificador serializable (UUID).
- ❌ Asumir 1 instrumento global en cualquier punto. Siempre piensa en N.
- ❌ Romper RT-safety en `process()` para "una optimización rápida".
- ❌ Romper la persistencia sin migración. Si subes `ProjectSnapshot.schemaVersion`, escribe el migrador de v(N-1) a vN.

## 10. Plan vivo

Estado del roadmap mergeado en `main`:

- **M0–M7** core MVP completo.
- **R1–R4** refactor modular (registry self-registering, ProjectGraph, ProjectController, MixerModule paramétrico + InstrumentUIRegistry).
- **M11-A,B,C,D,E,F,G,H** App Store readiness (privacy, onboarding, i18n, accesibilidad, AppIcon, default seed pattern, debug HUD, synth knob units).
- **M2.5** dispatch de eventos indexado por nodeId.
- **M5.5** scheduling sample-accurate intra-buffer (frameOffset en SPSC) + sequencer Swift a 500 Hz.
- **M7.5 / M7.5+** stems export por track + offline WAV render (faster-than-realtime).
- **M9** mixer meters dinámicos + 5 efectos nuevos (compressor, EQ, chorus, distortion, filter).
- **Instrumentos M8 family**: SubtractiveSynth, FMSynth, WavetableSynth, BeatBox.
- **ChipsMIDI** real (CoreMIDI virtual destination con dispatch a synth activo).
- **CommandBus** (ChipsCore) infraestructura de undo/redo.
- **iPad layout adaptations** (sidebar/topbar adaptan al size class regular).

Lo siguiente, en orden razonable de impacto:

1. Cablear acciones de UI a `Command`s (envolver `setParameter`, `addNode`, `removeNode`, `connect`, etc.) y exponer un undo/redo button en el top bar.
2. UI específica para cada instrumento nuevo (BeatBox: 8 pads en grid; FM: visualizador del modulator; Wavetable: render de la wavetable).
3. AUv3 host (hostear instrumentos/efectos de terceros) — fuera de scope MVP, pero abrirá la puerta a tener mucho más sin escribir DSP.
4. Sample-accurate sequencer driver en C++ (audio thread) consumiendo el `frameOffset` ya disponible.
5. App Store ship: completar Privacy Policy URL, Terms URL, App Store screenshots/copy. Esto bloquea solo el envío, no la app.
