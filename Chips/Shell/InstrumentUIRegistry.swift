import ChipsCore
import UIKit

/// Registry de builders de UI por `typeId` de módulo. Permite que cualquier
/// módulo nuevo (instrumento o efecto) declare su panel custom sin tocar el
/// AppShell ni la lista de tipos hardcoded en la app.
///
/// Si un `typeId` no tiene builder registrado, `makePanel` devuelve un
/// `GenericInstrumentPanelViewController` que renderiza un knob por cada
/// `ParameterSpec` expuesto por el módulo.
@MainActor
enum InstrumentUIRegistry {
    typealias Builder = (NodeRef, ProjectController) -> UIViewController

    private static var builders: [String: Builder] = [:]

    static func register(typeId: String, builder: @escaping Builder) {
        builders[typeId] = builder
    }

    static func unregister(typeId: String) {
        builders.removeValue(forKey: typeId)
    }

    static func hasBuilder(typeId: String) -> Bool {
        builders[typeId] != nil
    }

    static func makePanel(
        typeId: String,
        ref: NodeRef,
        controller: ProjectController
    ) -> UIViewController {
        if let builder = builders[typeId] {
            return builder(ref, controller)
        }
        return GenericInstrumentPanelViewController(ref: ref, controller: controller)
    }

    /// Builders built-in de Chips. Llamar una vez al boot. Cada módulo nuevo
    /// que llegue puede registrarse aquí o en su propio init.
    static func registerBuiltins() {
        register(typeId: "additive_synth") { _, controller in
            SynthesizerSectionViewController(controller: controller)
        }
    }
}
