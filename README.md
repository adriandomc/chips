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

## CI

Cada PR ejecuta build, tests, lint y snapshot tests en GitHub Actions (runner macOS).

## Licencia

Propietaria. Ver `LICENSE`.
