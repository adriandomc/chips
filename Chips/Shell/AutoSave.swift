import ChipsCore
import Foundation

/// Auto-guardado del proyecto en curso. Persiste un único archivo
/// `Autosave.chips` en el Documents directory cuando la escena pasa a
/// background, y lo restaura al siguiente launch. Comportamiento estándar
/// de un DAW comercial: el usuario no pierde sus cambios entre sesiones.
///
/// El archivo es reemplazable — Settings → SAVE / LOAD sigue siendo el
/// flujo explícito de "proyectos guardados". Autosave es solo el "estado
/// efímero" entre sesiones.
@MainActor
enum AutoSave {
    static let filename = "Autosave.chips"

    static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    /// Escribe el grafo a disco. Falla silenciosamente — no queremos
    /// interrumpir al usuario al ir a background con un alert.
    static func save(_ graph: ProjectGraph) {
        do {
            let data = try ProjectStorage.encode(graph)
            try data.write(to: url, options: .atomic)
        } catch {
            // Silent: backgrounding shouldn't surface errors.
        }
    }

    /// Devuelve el grafo guardado si existe y es decodable. Si está
    /// corrupto o no existe, devuelve nil — el caller debe hacer fallback
    /// a `defaultGraph()`.
    static func load() -> ProjectGraph? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return try? ProjectStorage.decodeProject(data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
