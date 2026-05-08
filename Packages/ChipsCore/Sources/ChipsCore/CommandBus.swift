import Foundation

/// Operación reversible que el `CommandBus` puede ejecutar y revertir.
///
/// El comando captura su estado interno (anterior y nuevo) en sus propias
/// propiedades para que `undo()` pueda restaurarlo. Es responsabilidad del
/// implementador no allocar ni bloquear en hot-paths del audio thread.
public protocol Command: AnyObject {
    /// Etiqueta human-readable para mostrar en la UI ("Add node", "Set tempo").
    var label: String { get }

    /// Aplica el comando.
    func perform()

    /// Revierte el comando al estado previo a `perform()`.
    func undo()
}

/// Pila lineal de comandos ejecutados con soporte de undo/redo.
///
/// Comportamiento estándar: tras ejecutar un comando, la pila de redo se vacía.
/// `maxDepth` limita el historial; comandos más antiguos se descartan.
@MainActor
public final class CommandBus {
    public let maxDepth: Int

    private var undoStack: [Command] = []
    private var redoStack: [Command] = []

    public init(maxDepth: Int = 200) {
        self.maxDepth = max(1, maxDepth)
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public var undoLabel: String? { undoStack.last?.label }
    public var redoLabel: String? { redoStack.last?.label }

    /// Ejecuta el comando y lo añade al historial de undo. Vacía la pila de redo.
    public func execute(_ command: Command) {
        command.perform()
        undoStack.append(command)
        if undoStack.count > maxDepth {
            undoStack.removeFirst(undoStack.count - maxDepth)
        }
        redoStack.removeAll(keepingCapacity: true)
    }

    /// Revierte el último comando ejecutado.
    @discardableResult
    public func undo() -> Bool {
        guard let command = undoStack.popLast() else { return false }
        command.undo()
        redoStack.append(command)
        return true
    }

    /// Re-ejecuta el último comando deshecho.
    @discardableResult
    public func redo() -> Bool {
        guard let command = redoStack.popLast() else { return false }
        command.perform()
        undoStack.append(command)
        return true
    }

    public func clear() {
        undoStack.removeAll(keepingCapacity: true)
        redoStack.removeAll(keepingCapacity: true)
    }
}

// MARK: Convenience commands

/// Comando genérico que ejecuta dos closures (perform/undo).
public final class BlockCommand: Command {
    public let label: String
    private let performBlock: () -> Void
    private let undoBlock: () -> Void

    public init(label: String, perform: @escaping () -> Void, undo: @escaping () -> Void) {
        self.label = label
        self.performBlock = perform
        self.undoBlock = undo
    }

    public func perform() { performBlock() }
    public func undo() { undoBlock() }
}
