// Graph.cpp — implementación del grafo dinámico.

#include "Graph.hpp"

#include <algorithm>
#include <cstring>
#include <queue>
#include <unordered_map>

namespace chips {

Graph::Graph() = default;

Graph::~Graph() {
    Plan* p = activePlan_.exchange(nullptr, std::memory_order_acq_rel);
    delete p;
}

void Graph::prepare(double sampleRate, int maxFrames) {
    sampleRate_ = sampleRate;
    maxFrames_ = maxFrames;
    for (auto& n : nodes_) {
        n.module->prepare(sampleRate, maxFrames);
    }
}

NodeId Graph::addNode(std::unique_ptr<IModule> module) {
    if (module == nullptr) {
        return kInvalidNodeId;
    }
    module->prepare(sampleRate_, maxFrames_);
    NodeId id = nextId_++;
    nodes_.push_back(Node{id, std::move(module)});
    return id;
}

bool Graph::removeNode(NodeId id) {
    auto it = std::find_if(nodes_.begin(), nodes_.end(), [id](const Node& n) { return n.id == id; });
    if (it == nodes_.end()) {
        return false;
    }
    connections_.erase(std::remove_if(connections_.begin(), connections_.end(),
                                      [id](const Connection& c) { return c.src == id || c.dst == id; }),
                       connections_.end());
    if (outputNodeId_ == id) {
        outputNodeId_ = kInvalidNodeId;
    }
    nodes_.erase(it);
    return true;
}

bool Graph::connect(NodeId src, int srcPort, NodeId dst, int dstPort) {
    Node* srcNode = findNode(src);
    Node* dstNode = findNode(dst);
    if (srcNode == nullptr || dstNode == nullptr) {
        return false;
    }
    if (srcPort < 0 || srcPort >= srcNode->module->numAudioOutputs()) {
        return false;
    }
    if (dstPort < 0 || dstPort >= dstNode->module->numAudioInputs()) {
        return false;
    }
    for (const auto& c : connections_) {
        if (c.dst == dst && c.dstPort == dstPort) {
            return false;
        }
    }
    connections_.push_back(Connection{src, srcPort, dst, dstPort});
    return true;
}

bool Graph::disconnect(NodeId src, int srcPort, NodeId dst, int dstPort) {
    auto it = std::find_if(connections_.begin(), connections_.end(), [&](const Connection& c) {
        return c.src == src && c.srcPort == srcPort && c.dst == dst && c.dstPort == dstPort;
    });
    if (it == connections_.end()) {
        return false;
    }
    connections_.erase(it);
    return true;
}

void Graph::setOutputNode(NodeId id) {
    outputNodeId_ = id;
}

Graph::Node* Graph::findNode(NodeId id) {
    auto it = std::find_if(nodes_.begin(), nodes_.end(), [id](const Node& n) { return n.id == id; });
    return it == nodes_.end() ? nullptr : &(*it);
}

IModule* Graph::node(NodeId id) {
    Node* n = findNode(id);
    return n == nullptr ? nullptr : n->module.get();
}

bool Graph::postParameter(NodeId nodeId, uint32_t paramId, float value) {
    return paramQueue_.push(ParameterEvent{ParameterEvent::Kind::Param, nodeId, paramId, value});
}

bool Graph::postNoteOn(NodeId nodeId, int midi, float velocity) {
    return paramQueue_.push(
        ParameterEvent{ParameterEvent::Kind::NoteOn, nodeId, static_cast<uint32_t>(midi), velocity});
}

bool Graph::postNoteOff(NodeId nodeId, int midi) {
    return paramQueue_.push(
        ParameterEvent{ParameterEvent::Kind::NoteOff, nodeId, static_cast<uint32_t>(midi), 0.0f});
}

bool Graph::compile() {
    if (outputNodeId_ == kInvalidNodeId) {
        return false;
    }
    if (findNode(outputNodeId_) == nullptr) {
        return false;
    }

    // 1. Topological sort vía Kahn's algorithm.
    std::unordered_map<NodeId, int> inDegree;
    std::unordered_map<NodeId, std::vector<NodeId>> adjacency;
    for (const auto& n : nodes_) {
        inDegree[n.id] = 0;
        adjacency[n.id] = {};
    }
    for (const auto& c : connections_) {
        adjacency[c.src].push_back(c.dst);
        inDegree[c.dst]++;
    }
    std::queue<NodeId> ready;
    for (const auto& kv : inDegree) {
        if (kv.second == 0) {
            ready.push(kv.first);
        }
    }
    std::vector<NodeId> sortedIds;
    sortedIds.reserve(nodes_.size());
    while (!ready.empty()) {
        NodeId id = ready.front();
        ready.pop();
        sortedIds.push_back(id);
        for (NodeId next : adjacency[id]) {
            if (--inDegree[next] == 0) {
                ready.push(next);
            }
        }
    }
    if (sortedIds.size() != nodes_.size()) {
        return false;  // ciclo detectado
    }

    // 2. Asignar buffers: uno por (nodeId, outputPort), más uno de silencio.
    std::unordered_map<uint64_t, int> outputBufferIndex;
    auto key = [](NodeId nodeId, int port) -> uint64_t {
        return (static_cast<uint64_t>(nodeId) << 32) | static_cast<uint32_t>(port);
    };
    int nextBuffer = 0;
    for (const auto& n : nodes_) {
        for (int p = 0; p < n.module->numAudioOutputs(); ++p) {
            outputBufferIndex[key(n.id, p)] = nextBuffer++;
        }
    }
    int silenceBuffer = nextBuffer++;

    // El plan tiene su propio BufferPool para evitar UAF si el audio thread
    // sigue leyendo el plan viejo mientras recompilamos.
    auto plan = std::make_unique<Plan>();
    plan->bufferPool.prepare(nextBuffer, maxFrames_);
    if (auto* silence = plan->bufferPool.buffer(silenceBuffer); silence != nullptr) {
        std::memset(silence, 0, static_cast<size_t>(maxFrames_) * sizeof(float));
    }

    // 3. Construir el Plan en orden topológico.
    plan->nodes.reserve(sortedIds.size());
    for (NodeId id : sortedIds) {
        Node* node = findNode(id);
        if (node == nullptr) {
            return false;
        }
        const int numIn = node->module->numAudioInputs();
        const int numOut = node->module->numAudioOutputs();
        PlannedNode pn;
        pn.module = node->module.get();
        pn.numInputs = numIn;
        pn.numOutputs = numOut;
        pn.inputs.assign(static_cast<size_t>(numIn), nullptr);
        pn.outputs.assign(static_cast<size_t>(numOut), nullptr);
        for (int p = 0; p < numOut; ++p) {
            pn.outputs[static_cast<size_t>(p)] = plan->bufferPool.buffer(outputBufferIndex[key(id, p)]);
        }
        for (int p = 0; p < numIn; ++p) {
            const float* src = plan->bufferPool.buffer(silenceBuffer);
            for (const auto& c : connections_) {
                if (c.dst == id && c.dstPort == p) {
                    src = plan->bufferPool.buffer(outputBufferIndex[key(c.src, c.srcPort)]);
                    break;
                }
            }
            pn.inputs[static_cast<size_t>(p)] = src;
        }
        plan->nodes.push_back(std::move(pn));
    }

    // 4. Output L/R: del nodo de salida (puerto 0 = L; 1 = R; mono → ambos).
    Node* outNode = findNode(outputNodeId_);
    if (outNode == nullptr) {
        return false;
    }
    const int outChannels = outNode->module->numAudioOutputs();
    if (outChannels < 1) {
        return false;
    }
    plan->outputL = plan->bufferPool.buffer(outputBufferIndex[key(outputNodeId_, 0)]);
    plan->outputR =
        outChannels >= 2 ? plan->bufferPool.buffer(outputBufferIndex[key(outputNodeId_, 1)]) : plan->outputL;

    // 5. Publish atómico. El plan viejo queda retenido (cleanup en compile siguiente).
    Plan* raw = plan.release();
    Plan* old = activePlan_.exchange(raw, std::memory_order_acq_rel);
    if (old != nullptr) {
        retainedPlans_.emplace_back(old);
    }
    return true;
}

void Graph::render(float* interleavedStereoOut, int frames) {
    if (interleavedStereoOut == nullptr || frames <= 0) {
        return;
    }
    Plan* plan = activePlan_.load(std::memory_order_acquire);
    if (plan == nullptr) {
        std::memset(interleavedStereoOut, 0, static_cast<size_t>(frames) * 2 * sizeof(float));
        return;
    }

    // Drain de eventos. M2/M4 broadcast: cada módulo recibe todos los eventos
    // y filtra por paramId/midi. M2.5 introducirá dispatch indexado por nodeId.
    {
        ParameterEvent ev;
        while (paramQueue_.pop(ev)) {
            for (auto& pn : plan->nodes) {
                switch (ev.kind) {
                case ParameterEvent::Kind::Param:
                    pn.module->handleParameterChange(ev.paramOrMidi, ev.value);
                    break;
                case ParameterEvent::Kind::NoteOn:
                    pn.module->handleNoteOn(static_cast<int>(ev.paramOrMidi), ev.value);
                    break;
                case ParameterEvent::Kind::NoteOff:
                    pn.module->handleNoteOff(static_cast<int>(ev.paramOrMidi));
                    break;
                }
            }
        }
    }

    ProcessContext ctx{};
    ctx.frames = frames;
    ctx.sampleRate = sampleRate_;
    ctx.tickPosition = 0;
    ctx.tempoBpm = 120.0;

    for (auto& pn : plan->nodes) {
        ctx.audioIn = pn.inputs.empty() ? nullptr : pn.inputs.data();
        ctx.audioOut = pn.outputs.empty() ? nullptr : pn.outputs.data();
        ctx.numAudioIn = pn.numInputs;
        ctx.numAudioOut = pn.numOutputs;
        pn.module->process(ctx);
    }

    const float* l = plan->outputL;
    const float* r = plan->outputR;
    if (l == nullptr || r == nullptr) {
        std::memset(interleavedStereoOut, 0, static_cast<size_t>(frames) * 2 * sizeof(float));
        return;
    }
    for (int i = 0; i < frames; ++i) {
        interleavedStereoOut[i * 2] = l[i];
        interleavedStereoOut[i * 2 + 1] = r[i];
    }
}

}  // namespace chips
