// ChipsEngine.cpp — implementación de la C ABI sobre el grafo C++.

#include "ChipsEngine/ChipsEngine.h"

#include "DspLoadTracker.hpp"
#include "Graph.hpp"
#include "PassthroughModule.hpp"
#include "SineGenerator.hpp"
#include "TestSourceModule.hpp"

#include <cstring>
#include <memory>
#include <new>
#include <string>

namespace {
constexpr const char* kVersion = "0.2.0-m2";

std::unique_ptr<chips::IModule> makeModuleFromTypeId(const char* typeId) {
    if (typeId == nullptr) {
        return nullptr;
    }
    const std::string id(typeId);
    if (id == CHIPS_NODE_TYPE_SINE) {
        return std::make_unique<chips::SineGenerator>();
    }
    if (id == CHIPS_NODE_TYPE_PASSTHROUGH) {
        return std::make_unique<chips::PassthroughModule>(2);  // stereo passthrough
    }
    if (id == CHIPS_NODE_TYPE_TEST_SOURCE) {
        return std::make_unique<chips::TestSourceModule>(64, 1);
    }
    return nullptr;
}
}  // namespace

struct ChipsEngineHandle {
    double sampleRate;
    int maxFrames;
    chips::Graph graph;
    chips::DspLoadTracker loadTracker;
};

extern "C" {

ChipsEngineHandle* chips_engine_create(double sample_rate, int max_frames) {
    if (sample_rate <= 0.0 || max_frames <= 0) {
        return nullptr;
    }
    auto* engine = new (std::nothrow) ChipsEngineHandle{};
    if (engine == nullptr) {
        return nullptr;
    }
    engine->sampleRate = sample_rate;
    engine->maxFrames = max_frames;
    engine->graph.prepare(sample_rate, max_frames);
    return engine;
}

void chips_engine_destroy(ChipsEngineHandle* engine) { delete engine; }

const char* chips_engine_version(void) { return kVersion; }

void chips_engine_render(ChipsEngineHandle* engine, float* interleaved_stereo_out, int frames) {
    if (engine == nullptr || interleaved_stereo_out == nullptr || frames <= 0) {
        return;
    }
    const auto t0 = engine->loadTracker.begin();
    engine->graph.render(interleaved_stereo_out, frames);
    engine->loadTracker.end(t0, frames, engine->sampleRate);
}

float chips_engine_dsp_load(const ChipsEngineHandle* engine) {
    if (engine == nullptr) {
        return 0.0f;
    }
    return engine->loadTracker.load();
}

double chips_engine_sample_rate(const ChipsEngineHandle* engine) {
    if (engine == nullptr) {
        return 0.0;
    }
    return engine->sampleRate;
}

ChipsNodeId chips_engine_add_node(ChipsEngineHandle* engine, const char* type_id) {
    if (engine == nullptr) {
        return CHIPS_INVALID_NODE_ID;
    }
    auto module = makeModuleFromTypeId(type_id);
    if (module == nullptr) {
        return CHIPS_INVALID_NODE_ID;
    }
    return engine->graph.addNode(std::move(module));
}

bool chips_engine_remove_node(ChipsEngineHandle* engine, ChipsNodeId node) {
    if (engine == nullptr) {
        return false;
    }
    return engine->graph.removeNode(node);
}

bool chips_engine_connect(ChipsEngineHandle* engine,
                          ChipsNodeId src, int src_port,
                          ChipsNodeId dst, int dst_port) {
    if (engine == nullptr) {
        return false;
    }
    return engine->graph.connect(src, src_port, dst, dst_port);
}

bool chips_engine_disconnect(ChipsEngineHandle* engine,
                             ChipsNodeId src, int src_port,
                             ChipsNodeId dst, int dst_port) {
    if (engine == nullptr) {
        return false;
    }
    return engine->graph.disconnect(src, src_port, dst, dst_port);
}

void chips_engine_set_output_node(ChipsEngineHandle* engine, ChipsNodeId node) {
    if (engine == nullptr) {
        return;
    }
    engine->graph.setOutputNode(node);
}

bool chips_engine_compile(ChipsEngineHandle* engine) {
    if (engine == nullptr) {
        return false;
    }
    return engine->graph.compile();
}

bool chips_engine_set_parameter(ChipsEngineHandle* engine,
                                ChipsNodeId node,
                                uint32_t param_id,
                                float value) {
    if (engine == nullptr) {
        return false;
    }
    return engine->graph.postParameter(node, param_id, value);
}

}  // extern "C"
