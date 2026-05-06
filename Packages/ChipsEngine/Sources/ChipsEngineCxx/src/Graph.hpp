// Graph.hpp — grafo dinámico de IModules con publicación lock-free.

#ifndef CHIPS_GRAPH_HPP
#define CHIPS_GRAPH_HPP

#include "BufferPool.hpp"
#include "IModule.hpp"
#include "SpscQueue.hpp"

#include <atomic>
#include <cstdint>
#include <memory>
#include <vector>

namespace chips {

using NodeId = uint32_t;
constexpr NodeId kInvalidNodeId = 0;

struct ParameterEvent {
    NodeId nodeId;
    uint32_t paramId;
    float value;
};

class Graph {
public:
    Graph();
    ~Graph();

    Graph(const Graph&) = delete;
    Graph& operator=(const Graph&) = delete;

    /// Llamado desde control thread antes de empezar audio.
    void prepare(double sampleRate, int maxFrames);

    /// Añade un nodo y devuelve su ID estable. El grafo toma ownership.
    NodeId addNode(std::unique_ptr<IModule> module);

    /// Elimina un nodo y todas sus conexiones. Requiere recompilar.
    bool removeNode(NodeId id);

    /// Conecta src.outPort -> dst.inPort. Devuelve false si IDs/puertos inválidos
    /// o si ya existe una conexión a ese input (un destino = un origen).
    bool connect(NodeId src, int srcPort, NodeId dst, int dstPort);

    /// Desconecta. Devuelve false si no existía la conexión.
    bool disconnect(NodeId src, int srcPort, NodeId dst, int dstPort);

    /// Define el nodo cuya salida (puertos 0 y 1) se enviará al output del engine.
    void setOutputNode(NodeId id);

    /// Recompila el plan de render. Devuelve false si hay ciclo o config inválida.
    /// Publica el nuevo plan al audio thread vía atomic swap.
    bool compile();

    /// Obtiene un módulo por ID. Llamable desde control thread.
    IModule* node(NodeId id);

    /// Encola un cambio de parámetro (control thread). Devuelve false si la cola
    /// está llena (drop policy: el cambio se pierde, llamador debe reintentar).
    bool postParameter(NodeId nodeId, uint32_t paramId, float value);

    /// RT-safe: renderiza `frames` muestras al buffer interleaved stereo.
    void render(float* interleavedStereoOut, int frames);

private:
    struct Connection {
        NodeId src;
        int srcPort;
        NodeId dst;
        int dstPort;
    };

    struct Node {
        NodeId id;
        std::unique_ptr<IModule> module;
    };

    struct PlannedNode {
        IModule* module;
        std::vector<const float*> inputs;  // pointers a buffers del pool (o nullptr para silencio)
        std::vector<float*> outputs;       // pointers a buffers del pool
        int numInputs;
        int numOutputs;
    };

    struct Plan {
        BufferPool bufferPool;  // pool propio del plan; evita UAF al recompilar
        std::vector<PlannedNode> nodes;
        const float* outputL = nullptr;  // buffer del pool que será L del engine
        const float* outputR = nullptr;
    };

    Node* findNode(NodeId id);

    std::vector<Node> nodes_;
    std::vector<Connection> connections_;
    NodeId nextId_ = 1;
    NodeId outputNodeId_ = kInvalidNodeId;

    double sampleRate_ = 48000.0;
    int maxFrames_ = 1024;

    std::atomic<Plan*> activePlan_{nullptr};
    std::vector<std::unique_ptr<Plan>> retainedPlans_;  // control-thread only

    SpscQueue<ParameterEvent, 1024> paramQueue_;
};

}  // namespace chips

#endif  // CHIPS_GRAPH_HPP
