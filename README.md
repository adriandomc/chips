# Chips

DAW modular para iOS (y posteriormente iPadOS) inspirado conceptualmente en Caustic. Arquitectura sin restricción de slots: cualquier número de instrumentos y efectos limitado solo por el CPU del dispositivo.

## Estado

En desarrollo activo — milestone **M0 (Fundamentos)**. Roadmap completo en el plan de acción interno.

## Stack

- **Lenguajes**: Swift 6 (control plane) + C++17 (DSP).
- **UI**: UIKit + CoreAnimation/CoreGraphics, custom render. `MTKView` para componentes intensivos. Sin SwiftUI en superficies de producto.
- **Audio host**: `AVAudioEngine` con un único `AVAudioSourceNode` que delega en el grafo C++.
- **Audio DSP**: C++17 con utilidades de `Accelerate` (vDSP) y Soundpipe (vendoreado, MIT).
- **MIDI**: `CoreMIDI` directo.
- **Persistencia**: bundle `.chips` (manifest JSON + assets) vía `UIDocument`.
- **Package manager**: Swift Package Manager exclusivamente.
- **Plataforma mínima**: iOS 17.

## Estructura

```
chips/
├── Chips/                  App target (AppDelegate, SceneDelegate, ViewController, Assets)
├── Packages/
│   ├── ChipsCore/          Modelos de proyecto, persistencia, undo, command bus
│   ├── ChipsEngine/        DSP graph y módulos (C++ + facade Swift)
│   ├── ChipsAudioHost/     AVAudioEngine, AVAudioSession, route handling
│   ├── ChipsMIDI/          CoreMIDI wrapper
│   ├── ChipsUIKit/         Componentes UI custom (knob, slider, meter, ...)
│   ├── ChipsModules/       Umbrella de módulos (additive synth, delay, reverb, ...)
│   └── ChipsTesting/       Helpers de test (golden audio, fixtures)
├── project.yml             XcodeGen
├── fastlane/               Lanes de TestFlight / App Store
├── .github/workflows/      CI
└── docs/                   Documentación interna
```

## Setup local (macOS)

Prerequisitos:

- macOS Sonoma 14.4+ (Sequoia 15.x recomendado).
- Xcode 16.0+.
- Homebrew con: `xcodegen`, `swiftlint`, `swiftformat`, `clang-format`, `xcbeautify`, `fastlane`.

```sh
brew install xcodegen swiftlint swiftformat clang-format xcbeautify fastlane
xcodegen generate
open Chips.xcodeproj
```

El `.xcodeproj` no se commitea: se regenera desde `project.yml`.

## Probar en dispositivo físico

Recomendado para validar audio real (latencia, glitches, CPU del device).

1. Conecta el iPhone con cable USB.
2. En Xcode → target **Chips** → tab **Signing & Capabilities**:
   - Marca *Automatically manage signing*.
   - **Team**: tu Apple ID (basta el plan gratuito; el build caduca a los 7 días y se renueva al volver a correr).
3. En la barra superior cambia el destino del simulador a tu iPhone.
4. ⌘R.
5. La primera vez el iPhone te pedirá confiar en el certificado en
   *Ajustes → General → VPN y Gestión de Dispositivos*.

Qué esperar al primer launch:
- Onboarding de 4 pantallas (Welcome → Sequence → Sound design → Ship it).
  Pulsa SKIP para ir directo a la app.
- AppShell con sidebar a la izquierda (Sequencer, Mixer, Synthesizer, Grid,
  Settings, Help).
- En **Synthesizer**: toca el piano on-screen y debería sonar el AdditiveSynth
  (8 voces × 64 partials) con la ADSR y volumen por defecto.
- En **Mixer**: 8 channel strips con gain/pan/mute.
- En **Settings → ABOUT**: versión y plataforma de restaurar compras.

Para volver a ver el onboarding tras una prueba: borra y reinstala la app
(o reset manual del flag `com.adriandomc.chips.onboarding.completedVersion`
en `UserDefaults`).

### Troubleshooting común

- **No suena nada en device**: revisa volumen físico. El audio session usa
  `.playback`, que **suena aunque el switch lateral esté en silencio** (es
  un app de música). Si no oyes nada, prueba a desconectar/reconectar
  cualquier accesorio Bluetooth y reabre la app.
- **"Could not launch — provisioning"**: re-elige el Team y clean build folder
  (⇧⌘K).
- **Audio cortado al recibir llamada**: comportamiento esperado; el host
  registra interruption observers y reanuda al colgar.

## CI

Cada PR ejecuta build, tests, lint y snapshot tests en GitHub Actions (runner macOS).

## Licencia

Propietaria. Ver `LICENSE`.
