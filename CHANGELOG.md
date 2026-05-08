# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versionado: SemVer una vez alcanzada v1.0; antes, solo se registran milestones.

## [Unreleased]

### M11-C — i18n (en + es) con `Localizable.xcstrings`
- `Chips/Resources/Localizable.xcstrings`: catálogo único con ~70 claves
  cubriendo todas las superficies user-facing: secciones (sequencer,
  mixer, synth, grid, settings, help), botones de Settings (NEW, SAVE,
  LOAD, etc.), labels de campos (Project Name, Tempo, BPM, …), alertas
  (save success/error, load, export, stems), About completo (Privacy
  Policy, Terms, Licenses, Restore Purchases + hint, version format,
  copyright), Onboarding (4 páginas + botones SKIP/NEXT/GET STARTED),
  Mixer (Track N, Pan, EQ, Sends, M/S), generic panel empty state.
  Cada clave tiene `extractionState: manual` (no la sobreescribe Xcode
  al extraer) y traducciones `en` + `es`.
- `project.yml`: añade `knownRegions: [en, es, Base]` para que XcodeGen
  declare los regions en el .xcodeproj generado.
- Reemplaza strings hardcoded por `String(localized:)` en:
  - `Chips/AppSection.swift` (titles de cada sección).
  - `Chips/Sections/SettingsSectionViewController.swift` (todos los
    botones, fields, alertas — incluido manejo de format strings con
    `String(format:_:)` para los placeholders).
  - `Chips/Sections/AboutViewController.swift` (todo el texto user-facing,
    versión formateada con `about.version_format`).
  - `Chips/Sections/OnboardingPage.swift` (4 títulos + 4 subtítulos
    desde el catálogo).
  - `Chips/Sections/OnboardingViewController.swift` (botones SKIP, NEXT,
    GET STARTED).
  - `Chips/Sections/MixerSectionViewController.swift` (Track N,
    Pan, EQ, Sends, M, S).
  - `Chips/Sections/GenericInstrumentPanelViewController.swift` (empty).
  - `Chips/Sections/HelpSectionViewController.swift` (subtítulo).
  - `Chips/Sections/SequencerSectionViewController.swift` (Track N).
- Tests:
  - `testLocalizableCatalogHasEnAndEs`: parsea el `.xcstrings` y verifica
    que las claves críticas existen en en + es. Si Xcode no expone el
    fuente como recurso, el test cede al de runtime.
  - `testLocalizedKeysResolveAtRuntime`: `String(localized:)` devuelve
    un valor distinto de la clave para cuatro claves canarias.

Pendiente: localizar SynthesizerSectionViewController (knobs internos)
y GridSectionViewController. Lo dejo para una PR posterior porque su
copy depende de cambios visuales que aún no he tocado.

Stack: M11-C basada sobre M11-B.

### M11-B — Onboarding mínimo (4 páginas) al primer launch
- `Chips/Sections/OnboardingPage.swift`: enum con 4 páginas (Welcome,
  Sequence, Sound design, Ship it).
- `Chips/Sections/OnboardingIconView.swift`: glifo geométrico por
  página dibujado vía CGContext.
- `Chips/Sections/OnboardingViewController.swift`: host @MainActor con
  cross-fade, dots de página, botones SKIP / NEXT / GET STARTED.
- `Chips/Shell/OnboardingState.swift`: gate persistido en UserDefaults,
  versionado por entero.
- `SceneDelegate`: gate antes del AppShell, cross-fade al completar.
- `PrivacyInfo.xcprivacy`: añade UserDefaults reason CA92.1.
- Tests: round-trip estado, contenido de páginas, NEXT × 4 completa,
  SKIP completa, manifesto declara reason.

### M11-H — Synth knob units para VoiceOver
- `SynthesizerSectionViewController`: cada knob recibe un
  `accessibilityValueFormatter` apropiado:
  - **VOLUME / SUSTAIN / TUNE (tilt)** → percentFormatter
    (`"50%"`, `"70%"`).
  - **ATTACK / DECAY / RELEASE** → timeFormatter (`"10 ms"`,
    `"150 ms"`, `"1.5 s"` — ms si <1s, s con un decimal si >=1s).
- Antes los knobs caían al fallback default `"%.2f"` que no es legible
  cuando el valor real es un tiempo en segundos o un porcentaje.

### M11-G — Debug HUD overlay (DSP load, sample rate, buffer)
- `Chips/Shell/DebugHUDView.swift`: vista flotante (DEBUG-only) que
  muestra `"DSP X.X%  48kHz  256"` en la esquina superior derecha del
  AppShell. Polling a 5 Hz vía `Timer` que lee `host.engine.dspLoad`.
  Tap → colapsa a un punto. La clase entera vive bajo `#if DEBUG`, no
  existe en builds Release.
- `AppShellViewController`: en DEBUG monta el HUD anclado al sidebar
  trailing y al topBar bottom. `startPolling()` arranca el timer.
- Útil durante el primer test en device para ver si el grafo cabe en
  el budget de CPU sin abrir Instruments.
- Test (`#if DEBUG`): verifica que el HUD está montado en el subview
  tree del shell tras `loadViewIfNeeded()`.

### M11-E — Device test readiness (AppIcon + run-on-device docs)
- `Chips/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` (1024×1024):
  icono geométrico con la identidad del app — 4 tiles de la paleta cálida
  (pink / mint / cyan / peach) en cuadrícula 2×2, sobre fondo
  `contentBackground`, con strokes oscuros — espeja el glifo de la página
  Welcome del onboarding. Generado vía Pillow desde la paleta de
  `ChipsTheme.trackPalette`.
- `Contents.json`: declara `AppIcon-1024.png` para el slot universal iOS.
- `README.md`: nueva sección **"Probar en dispositivo físico"** con
  pre-reqs, pasos para signing, qué esperar al primer launch y
  troubleshooting común.

Sin tocar runtime — polish para que la primera experiencia en device
sea fluida (icon visible en home + guía de qué probar).

### M8 piloto — SubtractiveSynth (prueba del plug-and-play)
- `Packages/ChipsEngine/Sources/ChipsEngineCxx/src/SubtractiveSynth.{hpp,cpp}`:
  saw monosynth + biquad LP filter (RBJ cookbook) + ADSR. Implementa
  `IModule` con typeId `"subtractive_synth"` y 7 parámetros (volume,
  cutoff, resonance, attack, decay, sustain, release) con units físicas
  (Hz, s).
- Auto-registro vía `ModuleRegistry` con `[[gnu::used]]`. `forceLink()`
  añadido al `touchAllModules()` de `ChipsEngine.cpp`.
- Tests: aparece en `registeredTypes`, `addNode(typeId:)` con 7 specs,
  tras `sendNoteOn` el render produce audio con RMS > 0.01.

Demostración concreta de la fundación modular cerrada en R1–R4.

### M11-D — Accesibilidad VoiceOver para componentes UI custom
- `ChipsKnob`/`ChipsFader`: `traits = .adjustable`, `accessibilityValue`
  formateable, increment/decrement con step configurable, dispara
  `.valueChanged`.
- `ChipsButton`: `.button`, label espejea title.
- `ChipsIconButton`: `.button` + `.selected` dinámico.
- `ChipsTransportButton`: defaults Play/Stop.
- `SidebarView`: cada icon button recibe `section.title`.
- `MixerSection`: labels humanos (Track N gain, Center, Mute, Solo).
- `GenericInstrumentPanelViewController`: knobs usan `spec.unit` en el
  formatter (`"0.50 Hz"`, `"1.20 dB"`).
- Tests: traits, label/value, increment/decrement, selected.

### M11-A — Privacy manifest + StoreKit 2 scaffold + About screen
- `Chips/PrivacyInfo.xcprivacy`: declara `NSPrivacyAccessedAPICategorySystemBootTime`
  con razón `35F9.1` por usar `CACurrentMediaTime()` en `SequencerEngine`
  (medir tiempo transcurrido entre eventos del transport). `NSPrivacyTracking`
  explícitamente `false` y sin `TrackingDomains`/`CollectedDataTypes`.
- `Chips/Shell/EntitlementManager.swift`: actor `@MainActor` que verifica
  `AppTransaction.shared` (recibo de compra) en builds de App Store/TestFlight
  y queda siempre `isEntitled = true` en DEBUG (desarrollo local sin StoreKit
  configuration). `restorePurchases()` llama a `AppStore.sync()` y revalida
  el recibo — necesario aunque la app sea paid-up-front (Guideline 3.1.1).
  `bootstrap()` se invoca al arrancar la escena.
- `Chips/Sections/AboutViewController.swift`: pantalla modal con identidad
  (Chips + version + build), placeholders de Privacy Policy, Terms y Open
  Source Licenses (URLs pendientes hasta publicar el dominio), bloque
  "Restore Purchases" que delega a `EntitlementManager`, y footer de
  copyright. Diseño consistente: `contentBackground`, mono para identidad,
  body para legales, separadores con `panelStroke`.
- `SettingsSectionViewController`: añade botón "ABOUT" al final que presenta
  `AboutViewController` modal en `formSheet` envuelto en `UINavigationController`.
- `SceneDelegate`: dispara `Task { await EntitlementManager.shared.bootstrap() }`
  inmediatamente tras montar el window (no bloqueante).
- Tests:
  - `testEntitlementManagerInDebugIsEntitled`: garantiza que en DEBUG arranca
    siempre con `isEntitled = true` (no depende de StoreKit configuration).
  - `testPrivacyManifestDeclaresSystemBootTimeReason`: parsea el `.xcprivacy`
    embebido en el bundle y verifica que declara SystemBootTime con razón
    35F9.1 — bloquea regresiones que rompan App Review.

Bloquea solo M11 final lo que necesita el usuario (Apple Developer Program,
Privacy Policy URL, Terms URL, App Store assets); las URLs son placeholders
en código, fáciles de sustituir.

### R4 — Modular foundation: UI generadora + Mixer paramétrico (cierra fundación)
- C++ `MixerModule` paramétrico: `MixerModule(int numChannels = 8)`. Storage
  `std::vector<Channel>` y `std::vector<ParamSpec>` con nombres en un
  `std::vector<std::string>` reservado a la capacidad final (los `c_str()`
  no se invalidan). `kMaxChannels = 64` como techo razonable. Default
  factory pasa de 4 a 8 canales — concuerda con el mockup.
- Swift: `InstrumentUIRegistry` MainActor-aislado: `register(typeId:builder:)`,
  `makePanel(typeId:ref:controller:)`. Si no hay builder, devuelve
  `GenericInstrumentPanelViewController` que itera los `ParameterSpec` del
  módulo y crea un knob por cada uno (cualquier módulo es **utilizable
  inmediatamente** sin escribir UI específica).
- `InstrumentUIRegistry.registerBuiltins()` registra el panel custom del
  AdditiveSynth (`SynthesizerSectionViewController`). Llamado al boot
  desde `SceneDelegate`. Cualquier nuevo módulo que llegue puede registrar
  su builder en su propio init/init de plugin.
- `MixerSectionViewController` consulta `numChannels` real al MixerModule
  en runtime (vía `parameterCount/3`). Pinta tantos channel strips como
  canales reales tenga el nodo. Ya no hay strips "visuales no cableados".
- Tests:
  - Mixer default expone 24 specs (8 canales × 3 params).
  - InstrumentUIRegistry fallback a panel genérico para tipos no registrados.
  - InstrumentUIRegistry usa builder registrado cuando existe.
  - Controller expone numChannels correcto al consumir el mixer.

**Cierra la fundación modular.** Tras R4, añadir un BeatBox es:

1. `Packages/ChipsEngine/Sources/ChipsEngineCxx/src/BeatBox.{hpp,cpp}` — DSP RT-safe + ParamSpecs + auto-registro en ModuleRegistry.
2. (Opcional) `Chips/Sections/BeatBoxPanelViewController.swift` — panel custom; si no, se usa el genérico con knobs auto-generados.
3. (Opcional) Registrar el builder en `InstrumentUIRegistry.registerBuiltins()`.

**Sin tocar el coordinator, el snapshot, el motor ni la app shell.** El instrumento es plug-and-play.

### R3 — Modular foundation: ProjectController reemplaza AudioCoordinator (en curso)
- `AudioCoordinator` eliminado. Sustituido por `ProjectController`
  (`Chips/Shell/ProjectController.swift`), MainActor-aislado, dueño del
  `ChipsAudioHost` y el `SequencerEngine`.
- **Single source of truth**: `private(set) var graph: ProjectGraph`. Todo
  cambio (add/remove node, connect, setParameter) actualiza el modelo y
  recompila el motor C++ desde él. Mapa interno `nodeIds: [NodeRef:
  ChipsNodeId]` para traducir entre identidad estable y handle efímero.
- **Plug-and-play**:
  - `addNode(typeId:displayName:) throws -> NodeRef` añade *cualquier* tipo
    registrado en `ModuleRegistry` (no requiere caso en el coordinator).
  - `removeNode(_:)`, `setParameter(of:paramName:value:)` (busca paramId
    via `parameterSpecs(of:)` del engine), `sendNoteOn/Off`, etc.
- **Routing track→instrumento real**: el delegate del sequencer ahora
  enruta cada nota al `track.instrumentRef`. El default graph asigna el
  synth como instrumento de cada track creado por la Grid.
- **Persistencia v2-first**: `currentGraph(name:author:)` produce un
  `ProjectGraph` serializable; `apply(graph:)` reconstruye el motor desde
  uno cargado. `ProjectStorage.decodeProject` migra v1 transparentemente.
- **Export WAV** sigue produciendo 16-bit stereo a través del nuevo
  controller, con la misma limitación documentada (render en tiempo real).
- Swift facade: `ChipsEngine.addNode(typeId: String)` overload añadido
  para tipos arbitrarios fuera del enum `ChipsNodeType`.

App refactor:
- `SceneDelegate` instancia `ProjectController` con `defaultGraph()`.
- `AppShellViewController(controller:)`.
- `SynthesizerSectionViewController(controller:)` lee/escribe parámetros
  via `controller.setParameter(of: synthRef, paramName:, value:)`.
- `MixerSectionViewController` los strips usan
  `setParameter(of: mixerRef, paramName: "ch<N>_<gain|pan|mute>", value:)`.
- `GridSectionViewController` crea tracks con `instrumentRef = controller.synthRef`.
  Si el grafo cargado ya trae tracks, los respeta.
- `SettingsSectionViewController` opera sobre `ProjectGraph`: NEW aplica
  default; SAVE escribe v2; LOAD migra v1 si hace falta.

Tests:
- `ProjectController` inicializa con default graph (refs no nil).
- `AppShell` carga.
- `setParameter(of:paramName:)` persiste el cambio en el `graph`.
- `currentGraph()` refleja edits de tempo y parámetros del synth.

R4 (siguiente PR) traerá la UI generadora desde metadata + `MixerModule`
paramétrico (numChannels). Tras eso, añadir un BeatBox será **3 archivos**
nuevos (BeatBox.hpp/.cpp + opcional BeatBoxPanelViewController.swift)
sin editar nada del coordinator, snapshot ni motor.

### R2 — Modular foundation: ProjectGraph dinámico + migrator v1→v2 (en curso)
- ChipsCore: `ProjectGraph` (Codable, schemaVersion=2). Modelo serializable
  del grafo del proyecto: lista de `NodeInstance` (typeId + displayName +
  diccionario `parameters: [String: Float]`), lista de `ConnectionDescriptor`
  (src/srcPort → dst/dstPort), `outputNodeRef`, `tracks`.
- `NodeRef = UUID`: identidad estable que sobrevive al rebuild del grafo
  C++ (los `ChipsNodeId` UInt32 son efímeros, asignados por `addNode`).
- `Track` extendido con `instrumentRef: NodeRef?`. Default nil; sequencer
  no enruta notas si es nil. R3 lo aprovechará para multi-instrumento.
- `ProjectMigrator.migrateV1ToV2` reproduce la cadena heredada
  (synth → mixer → delay → reverb → output) como nodos+conexiones
  explícitas, copiando todos los parámetros por nombre. Tracks heredados
  se enrutan al synth migrado.
- `ProjectStorage` ahora soporta ambos formatos:
  - `encode(_:ProjectGraph)` y `encode(_:ProjectSnapshot)` (legacy).
  - `decodeProject(_:)` auto-detecta `schemaVersion`: v1 se migra
    transparentemente; v2 directo; otros valores → throw.
  - `decode(_:)` legacy mantenido para AudioCoordinator hasta R3.
- ProjectSnapshot v1 se mantiene intacto; ningún proyecto guardado se
  rompe por este cambio.

Tests offline (5):
- ProjectGraph round-trip Codable (4 nodos + 1 track).
- Migrator produce 4 nodos / 6 conexiones / output=reverb.
- decodeProject sobre payload v1 devuelve graph v2 con 4 nodos.
- decodeProject rechaza schemas futuros (v99).
- Track.instrumentRef sobrevive Codable.

Sin cambios en el motor C++ ni en la app — R2 es exclusivamente del
modelo de datos. R3 introducirá `ProjectController` que consume este
modelo y reemplaza `AudioCoordinator`.

### R1 — Modular foundation: ModuleRegistry + metadata API (en curso)
- C++ `ModuleRegistry` singleton self-registering. Cada módulo añade un
  registro estático en su `.cpp` (con `[[gnu::used]]`); para asegurar
  que el linker incluye el object file en la static lib de SwiftPM,
  cada módulo expone `static void forceLink()` y `ChipsEngine.cpp`
  llama todos via `touchAllModules()` antes del primer `create`.
- `IModule` extendido con introspección no-RT:
  - `typeId()` (puro virtual): identificador estable.
  - `numParameters()` / `parameterAt(index)`: defaults que devuelven 0
    y `ParamSpec{}` para módulos sin parámetros expuestos.
- `ParamSpec { paramId, name, unit, minValue, maxValue, defaultValue }`
  con cadenas de vida estática.
- `makeModuleFromTypeId` reducido a un wrapper sobre el registry. Ya no
  hay switch/if-else por tipo en el motor.
- C ABI extendida:
  - `chips_engine_node_type_id`, `chips_engine_node_param_count`,
    `chips_engine_node_param_at(index, ChipsParamSpec*)`.
  - `chips_engine_registered_type_count`, `chips_engine_registered_type_at`.
- Swift facade: `ChipsEngine.registeredTypes`, `nodeTypeId(_:)`,
  `parameterCount(of:)`, `parameterSpec(of:at:)`, `parameterSpecs(of:)`,
  struct `ParameterSpec` (Hashable, Sendable).
- Tests offline (5): registry contiene los 7 tipos built-in; nodeTypeId
  refleja el tipo creado; AdditiveSynth expone 6 specs con nombres y
  unidades correctos; Passthrough expone 0 specs; Mixer expone 12
  (4 canales × gain/pan/mute).

Migración de los 7 módulos existentes (sine, passthrough, test_source,
additive_synth, mixer, delay, reverb) al pattern de auto-registro.
**Ningún cambio de comportamiento de runtime**: misma cadena de audio,
mismos parámetros con los mismos paramIds — solo cambia la forma en
que se descubren los tipos y se expone su metadata.

### M7 — Persistencia + Export WAV (en curso)
- ChipsCore: `ProjectSnapshot` Codable con `schemaVersion=1`. Captura
  nombre, autor, tempo, tracks (incluyendo patterns), settings de synth,
  mixer (4 canales), delay y reverb. `SynthSettings` /
  `MixerChannelSettings` / `DelaySettings` / `ReverbSettings` con defaults.
- ChipsCore: `ProjectStorage` (encode/decode JSON) + rechazo de schemas
  futuros desconocidos.
- ChipsCore: `WavWriter.writeStereoPCM16` — escribe RIFF/WAVE PCM
  16-bit stereo con clamping y conversión float→int16.
- `AudioCoordinator`: trackea `lastSynthSettings` / `lastMixerSettings` /
  `lastDelaySettings` / `lastReverbSettings` en cada setter para poder
  serializar sin leer el engine. `captureSnapshot(name:author:)`,
  `apply(snapshot:)`, `exportWav(to:seconds:)`.
- Sección Settings cableada:
  - **NEW** aplica un snapshot por defecto.
  - **SAVE** escribe a `Documents/<name>.chips` (JSON).
  - **LOAD** muestra un action sheet con los `.chips` guardados.
  - **MASTER TRACK** exporta 8 s a `Documents/<name>.wav` (16-bit
    stereo, 48 kHz).
  - STEMS → alert "pendiente M7.5".
- `Info.plist`: `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`
  para que la carpeta Documents sea accesible desde la app Files.
- Tests: ProjectSnapshot Codable round-trip, rechazo de schema 999, WAV
  header válido (RIFF/WAVE/fmt).

### M6 — Mixer + Delay + Reverb (en curso)
- C++ `MixerModule`: 4 canales stereo (8 inputs), gain/pan/mute por canal,
  suma a master stereo. ParamId codifica `(channel << 8) | kind`.
- C++ `DelayModule`: stereo con feedback ping-pong, time/feedback/wet.
  Buffer ring de hasta 2 s.
- C++ `ReverbModule`: estilo Schroeder (4 combs paralelos con damping
  one-pole + 2 allpass en serie). Parámetros: roomSize/damping/wet.
- Tipos registrados en C ABI: `mixer`, `delay`, `reverb`.
- Swift facade: enums `MixerParamKind`, `DelayParam`, `ReverbParam`,
  helpers `setMixerParameter`, `setParameter(_:delay:value:)`,
  `setParameter(_:reverb:value:)`.
- `AudioCoordinator` construye el grafo `synth→mixer→delay→reverb→output`
  con defaults musicales (delay 350 ms / fb 0.35 / wet 0.20; reverb
  room 0.7 / wet 0.20).
- `MixerSectionViewController` cablea fader/pan/mute de los primeros 4
  channel strips al `MixerModule` real (los strips 5–10 quedan visuales).
- Tests offline: mixer enruta sine con gain, mute produce silencio,
  cadena synth→mixer→delay→reverb produce audio E2E tras noteOn.

### M5 — Timeline + Sequencer (en curso)
- ChipsCore: tipos `PatternNote`, `Pattern`, `Track` (Codable, Sendable)
  con queries `notesStarting/Ending(in:to:)`. PPQ=480 estándar.
- ChipsCore: `TransportState` con tempo, currentTick, ppq, isPlaying.
  Helpers `tickSeconds` y `formatted` (formato "1.1.00").
- ChipsCore: `SequencerEngine` MainActor-isolated, timer-based @ 100 Hz.
  Mantiene tracks + tempo, delega note on/off al delegate, soporta loop
  infinito por wrap del pattern length. M5: control-thread, no
  sample-accurate (M5.5+ moverá scheduling al audio thread vía SPSC).
- `AudioCoordinator` ahora es `SequencerEngineDelegate`: dispatch de
  notas del sequencer al synth. Expone `play()/stop()` que arranca el
  host de audio y el sequencer juntos. `onTimecodeChange` y
  `onTickChange` para reflejar transport en la UI.
- App shell: top bar timecode label se actualiza con la posición del
  transport. Botones play/stop disparan `coordinator.play/stop`.
- Sección Grid: step sequencer 6 tracks × 16 steps con pitches base
  C3..A3. Click en celda toggleea nota; el playhead resalta el step
  actual con borde cyan al reproducir.
- Tests: round-trip Codable de Pattern, queries de notas en ventana,
  TransportState formatted/tickSeconds/clamping, SequencerEngine
  setTracks + delegate cableado.

### M4 — AdditiveSynth (en curso)
- C++ `AdsrEnvelope` lineal (header-only, RT-safe) con stages
  Idle/Attack/Decay/Sustain/Release.
- C++ `AdditiveSynth` polifónico: 8 voces × 16 partials. Cada voz tiene
  su propio envelope ADSR; las amplitudes de los partials son compartidas
  y se computan desde el parámetro `tilt` (0 = solo fundamental,
  1 = serie tipo saw 1/n normalizada). Voice stealing por round-robin.
- Extensión de `IModule`: `handleNoteOn(midi, velocity)` y `handleNoteOff(midi)`
  con default no-op (los efectos los ignoran).
- Extensión del SPSC del Graph: `ParameterEvent::Kind` discrimina entre
  `Param`, `NoteOn`, `NoteOff`. El drain en render() los dispatcha al
  módulo correspondiente.
- C ABI: `chips_engine_send_note_on` / `_off`. Tipo `additive_synth`
  registrado en `makeModuleFromTypeId`.
- Swift facade: `ChipsNodeType.additiveSynth`, `AdditiveSynthParam` enum
  (volume/attack/decay/sustain/release/tilt), `sendNoteOn` / `sendNoteOff`,
  `setParameter(_:additive:value:)`.
- `AudioCoordinator` reemplaza el sine generator por el AdditiveSynth.
  Defaults musicales: volume 0.5, A 10ms, D 150ms, S 0.7, R 400ms, tilt 0.5.
- `SynthesizerSectionViewController` cablea Volume + ADSR + tilt
  (mapeado al knob TUNE) al synth real. El teclado piano dispara
  `noteOn`/`noteOff` directos en el coordinator (la frecuencia ya no se
  setea desde Swift — el synth la calcula desde MIDI).
- Tests offline:
  - synth silencioso por defecto (sin notas).
  - sound after note on, RMS > 0.05 tras 4 bloques.
  - silence tras note off y release completo.

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
