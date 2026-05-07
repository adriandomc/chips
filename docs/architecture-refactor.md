# Architecture refactor — modular foundation

> Documento de propuesta. **No implementado**. Requiere aprobación del usuario
> antes de ejecutar (rompe la API del coordinator y el formato de proyecto).
> Asociado a `CLAUDE.md` § 7 y § 10.

## 1. Por qué (ahora)

Tras M0-M7 el MVP funciona, pero la auditoría arquitectónica encuentra que la **ideología modular se mantiene en C++ pero se rompe en Swift/App**. Concretamente:

- Añadir un BeatBox hoy implica editar **10+ puntos** distribuidos en el codebase.
- `ProjectSnapshot` no es extensible: subir un proyecto con un instrumento que el snapshot no contempla rompe el round-trip.
- `Track` no rutea a un instrumento concreto: todo va al único synth.
- `MixerModule` está limitado a 4 canales en compile time.
- `makeModuleFromTypeId` requiere editar el motor por cada tipo nuevo.

Si añadimos M8 (más instrumentos) sobre esta base, cada instrumento amplifica el problema. El refactor cuesta menos que la deuda que prevendría.

## 2. Diseño objetivo

### 2.1 Module registry self-registering (C++)

```cpp
// ModuleRegistry.hpp
namespace chips {
class ModuleRegistry {
public:
    using Factory = std::function<std::unique_ptr<IModule>()>;
    static ModuleRegistry& instance();
    bool register_(const std::string& typeId, Factory factory);
    std::unique_ptr<IModule> create(const std::string& typeId) const;
    std::vector<std::string> registeredTypes() const;
};
}  // namespace chips
```

Cada `XxxModule.cpp` se registra en un anonymous-namespace static initializer:

```cpp
namespace {
const bool kRegistered = chips::ModuleRegistry::instance().register_(
    "additive_synth", [] { return std::make_unique<chips::AdditiveSynth>(); });
}
```

`makeModuleFromTypeId` queda en una línea: `return ModuleRegistry::instance().create(typeId);`

⚠️ **Cuidado**: en SwiftPM static lib targets, el linker descarta símbolos no referenciados. Hay que forzar referencia con `__attribute__((used))` en cada registrar global, o un manifest "include all modules" en `ChipsEngine.cpp`.

### 2.2 Module metadata exposed via C ABI

Cada módulo declara sus parámetros (id, name, range, default, unit). El facade Swift puede listar tipos y parámetros para construir UIs genéricas.

```cpp
struct ParamSpec {
    uint32_t paramId;
    const char* name;
    const char* unit;
    float minValue;
    float maxValue;
    float defaultValue;
};

// IModule additions:
virtual int numParameters() const = 0;
virtual const ParamSpec* parameterAt(int index) const = 0;
virtual const char* typeId() const = 0;
```

C ABI:
```c
int chips_engine_node_param_count(handle, nodeId);
bool chips_engine_node_param_at(handle, nodeId, index, ParamSpec* out);
const char* chips_engine_node_type_id(handle, nodeId);
```

### 2.3 ProjectGraph: representación serializable del grafo

Reemplaza el `ProjectSnapshot` rígido por un modelo dinámico:

```swift
public struct ProjectGraph: Codable, Sendable {
    public var schemaVersion: Int = 2
    public var name: String
    public var author: String
    public var tempoBpm: Float

    public var nodes: [NodeInstance]
    public var connections: [ConnectionDescriptor]
    public var outputNodeRef: NodeRef
    public var tracks: [Track]  // Track ahora tiene instrumentRef

    public var createdAt: Date
    public var modifiedAt: Date
}

public struct NodeInstance: Codable, Sendable, Identifiable {
    public let id: NodeRef         // UUID estable, sobrevive al rebuild del grafo
    public var typeId: String      // "additive_synth", "beatbox", "delay", ...
    public var displayName: String
    public var parameters: [String: Float]  // paramId(uint32, hex) → value
    public var positionHint: CGPoint?       // para layout en una futura vista de rack
}

public struct ConnectionDescriptor: Codable, Sendable {
    public var src: NodeRef
    public var srcPort: Int
    public var dst: NodeRef
    public var dstPort: Int
}

public typealias NodeRef = UUID
```

`Track` gana un campo:
```swift
public struct Track: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var colorIndex: Int
    public var instrumentRef: NodeRef?  // nil = no enrutado
    public var patterns: [Pattern]
}
```

### 2.4 ProjectController (reemplaza AudioCoordinator)

```swift
@MainActor
final class ProjectController: SequencerEngineDelegate {
    public let host: ChipsAudioHost
    public private(set) var graph: ProjectGraph
    public let sequencer = SequencerEngine()

    /// Mapeo de NodeRef (estable) → ChipsNodeId (efímero, asignado por el engine).
    private var nodeIds: [NodeRef: ChipsNodeId] = [:]

    init(graph: ProjectGraph) throws {
        host = try ChipsAudioHost(...)
        self.graph = graph
        try rebuildEngineFromGraph()
        sequencer.delegate = self
    }

    /// Reconstruye el grafo C++ desde el modelo. Se llama tras cargar un
    /// proyecto, después de añadir/quitar nodos, etc.
    private func rebuildEngineFromGraph() throws {
        // 1. Limpiar engine: removeNode de todos los previos.
        // 2. addNode por cada NodeInstance, registrando NodeRef → ChipsNodeId.
        // 3. connect por cada ConnectionDescriptor.
        // 4. setOutputNode(nodeIds[graph.outputNodeRef]).
        // 5. compile().
        // 6. Aplicar parameters de cada NodeInstance.
    }

    public func addNode(typeId: String, displayName: String) throws -> NodeRef {
        // Crea NodeInstance, lo añade a graph.nodes, llama rebuild.
    }

    public func removeNode(_ ref: NodeRef) throws { ... }
    public func connect(_ src: NodeRef, srcPort: Int, _ dst: NodeRef, dstPort: Int) throws { ... }
    public func setOutput(_ ref: NodeRef) throws { ... }
    public func setParameter(_ ref: NodeRef, paramId: UInt32, value: Float) throws { ... }
    public func sendNoteOn(_ ref: NodeRef, midi: Int, velocity: Float) throws { ... }
    public func sendNoteOff(_ ref: NodeRef, midi: Int) throws { ... }

    // Sequencer routing usa instrumentRef del Track:
    func sequencer(noteOnFor track: Track, note: PatternNote) {
        guard let ref = track.instrumentRef, let nodeId = nodeIds[ref] else { return }
        host.engine.sendNoteOn(nodeId, midi: Int(note.midi), velocity: note.velocity)
    }
    // ...
}
```

### 2.5 MixerModule paramétrico

```cpp
class MixerModule : public IModule {
public:
    explicit MixerModule(int numChannels);
    // ...
private:
    int numChannels_;
    std::vector<Channel> channels_;
};
```

Constructor por defecto en el registry: `MixerModule(8)` (más razonable que 4 para el mockup).

### 2.6 Migración de proyectos guardados

Schema v1 (rígido) → v2 (graph). Migrador:

```swift
enum ProjectMigrator {
    static func migrate(legacyData: Data) throws -> ProjectGraph {
        let v1 = try JSONDecoder().decode(ProjectSnapshotV1.self, from: legacyData)
        // Construir un ProjectGraph equivalente:
        // synth → mixer → delay → reverb → output (la cadena hardcoded de v1).
        // Mapear settings → parameters.
        // Tracks → instrumentRef = synthRef.
    }
}
```

Snapshot v1 se mantiene en código (`ProjectSnapshotV1`) solo como input del migrador.

### 2.7 InstrumentUIRegistry (Swift)

Cada section/panel UI se registra para un `typeId`:

```swift
@MainActor
public enum InstrumentUIRegistry {
    public typealias Builder = (NodeRef, ProjectController) -> UIViewController
    private static var builders: [String: Builder] = [:]
    public static func register(typeId: String, builder: @escaping Builder) { ... }
    public static func makePanel(typeId: String, nodeRef: NodeRef, controller: ProjectController) -> UIViewController? { ... }
}
```

`SynthesizerSectionViewController` se reorganiza:
- Una vista "rack" que itera `controller.graph.nodes` y para cada uno consulta `InstrumentUIRegistry`.
- Si no hay UI registrada, fallback a una UI genérica generada desde `ParamSpec` (cada knob es un `ChipsKnob` con label y range del spec).

## 3. Roadmap de PRs

Sugerido: 4 PRs incrementales, cada uno mergeable independientemente.

### PR R1: ModuleRegistry + metadata API
- `ModuleRegistry.hpp/.cpp`.
- Migrar todos los módulos existentes a auto-registrarse.
- `IModule` gana `typeId()`, `numParameters()`, `parameterAt()`.
- C ABI gana funciones de inspección.
- Tests: registry contiene todos los tipos esperados; metadata no nil.
- **No rompe nada**: `makeModuleFromTypeId` queda como wrapper sobre el registry.

### PR R2: ProjectGraph + ProjectMigrator
- Añadir `ProjectGraph`, `NodeInstance`, etc. en ChipsCore.
- Mantener `ProjectSnapshot` como `ProjectSnapshotV1` (legacy).
- `ProjectMigrator.migrate(...)` produce ProjectGraph desde v1.
- Tests: round-trip ProjectGraph; v1 → v2 preserva datos.
- **No rompe nada**: aún no usado por la app.

### PR R3: ProjectController reemplaza AudioCoordinator
- Crear `ProjectController` con la API descrita.
- Refactor de `SettingsSectionViewController`, `SynthesizerSectionViewController`, `MixerSectionViewController`, `GridSectionViewController`, `AppShellViewController` para consumir `ProjectController` en vez de `AudioCoordinator`.
- `SceneDelegate` carga proyecto: si hay `Documents/last.chips` → migrar y abrir; sino, default fresh ProjectGraph.
- `Track.instrumentRef` se usa en el delegate del sequencer.
- **Rompe**: API del coordinator. No rompe persistencia (migrador transparente).

### PR R4: UI dinámica + MixerModule N
- `InstrumentUIRegistry` con builders por tipo.
- `RackSectionViewController` (puede ser la misma sección "Synthesizer" renombrada o una nueva) que muestra dinámicamente el panel del nodo seleccionado.
- UI generadora genérica desde `ParamSpec` para módulos sin UI custom.
- `MixerModule(numChannels:)` paramétrico; default a 8.
- `MixerSectionViewController` lee count del nodo en runtime.
- **Rompe**: Mixer settings v2 incluye `numChannels`.

Total estimado: ~3-5 días de trabajo distribuido en 4 PRs.

## 4. Riesgos

| Riesgo | Mitigación |
|--------|-----------|
| Self-registering linker descarta el símbolo | `__attribute__((used))` o referencia explícita en `ChipsEngine.cpp` (manifest `forceLinkAllModules()`) |
| Proyectos guardados se rompen | `ProjectMigrator` con tests exhaustivos contra fixtures v1 |
| Refactor del coordinator rompe varios callers | Hacerlo en un solo PR (R3) con compilación atómica |
| UI dinámica feels less polished | Mantener UI custom para AdditiveSynth (registro explícito); fallback genérico solo para nuevos módulos sin UI dedicada |
| Performance: rebuildEngineFromGraph en cada edición | Incremental: addNode/removeNode operan directo sobre el engine, solo recompilar si la topología cambió |

## 5. Alternativa rechazada

**No hacer el refactor y seguir con M8**. Cada nuevo instrumento añadiría:
- 1 set de campos rígidos al `ProjectSnapshot`.
- 1 set de propiedades hardcoded al `AudioCoordinator`.
- 1 set de métodos `setXxx`/`noteOn` específicos.
- 1 ViewController custom acoplado al coordinator.

Tras 4 instrumentos extra, el coordinator superaría las 600 líneas y el snapshot tendría una matriz combinatoria intratable. La deuda crece superlinealmente. **Rechazada**.

## 6. Decisiones que requiero del usuario

1. ¿**Apruebas el refactor antes de M8**? (mi recomendación: sí.)
2. ¿Algún cambio al diseño objetivo (§ 2)?
3. ¿Implementar como **stack de 4 PRs** o uno mega-PR? (yo prefiero 4 PRs por reviewability.)
4. ¿Mantener `AudioCoordinator` como facade thin sobre `ProjectController` para no romper completamente las UIs antes de R3, o saltarse y hacer la migración atómica?
