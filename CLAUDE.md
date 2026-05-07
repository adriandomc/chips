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

> Honesto: el motor (C++) está bien diseñado para modularidad. La capa Swift
> (Coordinator + ProjectSnapshot + algunas UIs) **viola la ideología**.
> Ver `docs/architecture-refactor.md` para el plan de remediación.

**Lo que sí cumple**:
- `Graph` (C++) admite topologías arbitrarias en runtime.
- `IModule` es genérico.
- `SpscQueue` y `ParameterEvent` discriminan kind (Param/NoteOn/NoteOff).
- `MixerModule` para uso interno es genérico (4 canales hoy, fácil extender).

**Lo que NO cumple (deuda)**:
- `AudioCoordinator` hardcodea el grafo en `init()` con `let synthNodeId/mixerNodeId/delayNodeId/reverbNodeId`. Añadir un BeatBox requiere reescribir el coordinator.
- `ProjectSnapshot` tiene campos rígidos (`synth: SynthSettings`, `delay: DelaySettings`, `reverb: ReverbSettings`). No admite proyectos con N instrumentos / M efectos.
- `Track` no tiene `instrumentNodeId`. El sequencer dispara todas las notas al synth único.
- `MixerModule.kMaxChannels = 4` constexpr.
- `makeModuleFromTypeId` es un switch/if-else manual; no hay registry self-registering.
- Las section views (`SynthesizerSectionViewController`) están hardcoded para AdditiveSynth.
- Los param enums (`AdditiveSynthParam`, etc.) viven en el facade Swift; no hay metadata (range, default, label) que un UI generador pueda consumir.

**Limitaciones de scope (no son bugs, son diferimientos documentados)**:
- Sequencer corre en control thread (no sample-accurate). M5.5+ → audio thread.
- Param dispatch broadcast a todos los nodos (drain del SPSC); funciona porque módulos ignoran paramIds desconocidos. nodeId-indexed dispatch en M2.5+.
- WAV export "vivo" (no faster-than-realtime). M7.5+ → offline render con sequencer manual.
- Sin meters dinámicos en mixer.
- UIs hardcoded por instrumento (M9+ podría añadir UI generadora desde metadata).

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

El roadmap del MVP v1.0 está completo en `main` (M0-M7 mergeados). Lo siguiente debería ser la **refactorización modular** descrita en `docs/architecture-refactor.md` antes de M8 (instrumentos adicionales). Sin esa refactorización, cada instrumento nuevo amplifica la deuda.
