// ChipsEngine.cpp — implementación de la C ABI sobre el grafo C++.

#include "ChipsEngine/ChipsEngine.h"

#include "AdditiveSynth.hpp"
#include "BeatBox.hpp"
#include "ChorusModule.hpp"
#include "CompressorModule.hpp"
#include "DelayModule.hpp"
#include "DistortionModule.hpp"
#include "DspLoadTracker.hpp"
#include "EQModule.hpp"
#include "FMSynth.hpp"
#include "FilterModule.hpp"
#include "Graph.hpp"
#include "MixerModule.hpp"
#include "ModuleRegistry.hpp"
#include "PassthroughModule.hpp"
#include "ReverbModule.hpp"
#include "SineGenerator.hpp"
#include "SubtractiveSynth.hpp"
#include "TestSourceModule.hpp"
#include "WavetableSynth.hpp"

#include <cstring>
#include <memory>
#include <new>
#include <string>
#include <vector>

namespace {
constexpr const char* kVersion = "0.3.0-r1";

/// Fuerza al linker a incluir los object files de cada módulo. Los registros
/// estáticos (en cada *Module.cpp) solo corren si el objeto se enlaza; en static
/// libs (SwiftPM target) los objetos sin símbolos referenciados se descartan.
/// Llamado una vez al primer create().
void touchAllModules() {
    chips::SineGenerator::forceLink();
    chips::PassthroughModule::forceLink();
    chips::TestSourceModule::forceLink();
    chips::AdditiveSynth::forceLink();
    chips::SubtractiveSynth::forceLink();
    chips::FMSynth::forceLink();
    chips::WavetableSynth::forceLink();
    chips::BeatBox::forceLink();
    chips::CompressorModule::forceLink();
    chips::EQModule::forceLink();
    chips::ChorusModule::forceLink();
    chips::DistortionModule::forceLink();
    chips::FilterModule::forceLink();
    chips::MixerModule::forceLink();
    chips::DelayModule::forceLink();
    chips::ReverbModule::forceLink();
}

void ensureModulesRegistered() {
    static const int sentinel = (touchAllModules(), 0);
    (void)sentinel;
}

std::unique_ptr<chips::IModule> makeModuleFromTypeId(const char* typeId) {
    if (typeId == nullptr) {
        return nullptr;
    }
    ensureModulesRegistered();
    return chips::ModuleRegistry::instance().create(std::string(typeId));
}
}  // namespace

struct ChipsEngineHandle {
    double sampleRate;
    int maxFrames;
    chips::Graph graph;
    chips::DspLoadTracker loadTracker;
    /// Tabla de typeIds para introspección sin lookup costoso del Graph.
    std::vector<std::string> registeredTypesCache;
};

extern "C" {

ChipsEngineHandle* chips_engine_create(double sample_rate, int max_frames) {
    if (sample_rate <= 0.0 || max_frames <= 0) {
        return nullptr;
    }
    ensureModulesRegistered();
    auto* engine = new (std::nothrow) ChipsEngineHandle{};
    if (engine == nullptr) {
        return nullptr;
    }
    engine->sampleRate = sample_rate;
    engine->maxFrames = max_frames;
    engine->graph.prepare(sample_rate, max_frames);
    engine->registeredTypesCache = chips::ModuleRegistry::instance().registeredTypes();
    return engine;
}

void chips_engine_destroy(ChipsEngineHandle* engine) {
    delete engine;
}

const char* chips_engine_version(void) {
    return kVersion;
}

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

bool chips_engine_connect(ChipsEngineHandle* engine, ChipsNodeId src, int src_port, ChipsNodeId dst, int dst_port) {
    if (engine == nullptr) {
        return false;
    }
    return engine->graph.connect(src, src_port, dst, dst_port);
}

bool chips_engine_disconnect(ChipsEngineHandle* engine, ChipsNodeId src, int src_port, ChipsNodeId dst, int dst_port) {
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

bool chips_engine_set_parameter(ChipsEngineHandle* engine, ChipsNodeId node, uint32_t param_id, float value) {
    if (engine == nullptr) {
        return false;
    }
    return engine->graph.postParameter(node, param_id, value);
}

bool chips_engine_send_note_on(ChipsEngineHandle* engine, ChipsNodeId node, int midi, float velocity) {
    if (engine == nullptr) {
        return false;
    }
    return engine->graph.postNoteOn(node, midi, velocity);
}

bool chips_engine_send_note_off(ChipsEngineHandle* engine, ChipsNodeId node, int midi) {
    if (engine == nullptr) {
        return false;
    }
    return engine->graph.postNoteOff(node, midi);
}

bool chips_engine_set_parameter_at(ChipsEngineHandle* engine, ChipsNodeId node, uint32_t param_id, float value,
                                   uint32_t frame_offset) {
    if (engine == nullptr) {
        return false;
    }
    return engine->graph.postParameter(node, param_id, value, frame_offset);
}

bool chips_engine_send_note_on_at(ChipsEngineHandle* engine, ChipsNodeId node, int midi, float velocity,
                                  uint32_t frame_offset) {
    if (engine == nullptr) {
        return false;
    }
    return engine->graph.postNoteOn(node, midi, velocity, frame_offset);
}

bool chips_engine_send_note_off_at(ChipsEngineHandle* engine, ChipsNodeId node, int midi, uint32_t frame_offset) {
    if (engine == nullptr) {
        return false;
    }
    return engine->graph.postNoteOff(node, midi, frame_offset);
}

// ---- Introspección (R1) ----

const char* chips_engine_node_type_id(ChipsEngineHandle* engine, ChipsNodeId node) {
    if (engine == nullptr) {
        return nullptr;
    }
    chips::IModule* module = engine->graph.node(node);
    return module == nullptr ? nullptr : module->typeId();
}

int chips_engine_node_param_count(ChipsEngineHandle* engine, ChipsNodeId node) {
    if (engine == nullptr) {
        return 0;
    }
    chips::IModule* module = engine->graph.node(node);
    return module == nullptr ? 0 : module->numParameters();
}

bool chips_engine_node_param_at(ChipsEngineHandle* engine, ChipsNodeId node, int index, ChipsParamSpec* out) {
    if (engine == nullptr || out == nullptr) {
        return false;
    }
    chips::IModule* module = engine->graph.node(node);
    if (module == nullptr || index < 0 || index >= module->numParameters()) {
        return false;
    }
    const chips::ParamSpec spec = module->parameterAt(index);
    out->param_id = spec.paramId;
    out->name = spec.name;
    out->unit = spec.unit;
    out->min_value = spec.minValue;
    out->max_value = spec.maxValue;
    out->default_value = spec.defaultValue;
    return true;
}

int chips_engine_registered_type_count(ChipsEngineHandle* engine) {
    if (engine == nullptr) {
        return 0;
    }
    return static_cast<int>(engine->registeredTypesCache.size());
}

const char* chips_engine_registered_type_at(ChipsEngineHandle* engine, int index) {
    if (engine == nullptr) {
        return nullptr;
    }
    if (index < 0 || index >= static_cast<int>(engine->registeredTypesCache.size())) {
        return nullptr;
    }
    return engine->registeredTypesCache[static_cast<size_t>(index)].c_str();
}

float chips_engine_mixer_channel_peak(ChipsEngineHandle* engine, ChipsNodeId node, int channel, bool is_left) {
    if (engine == nullptr) {
        return 0.0f;
    }
    chips::IModule* module = engine->graph.node(node);
    auto* mixer = dynamic_cast<chips::MixerModule*>(module);
    if (mixer == nullptr) {
        return 0.0f;
    }
    return mixer->channelPeak(channel, is_left);
}

float chips_engine_mixer_master_peak(ChipsEngineHandle* engine, ChipsNodeId node, bool is_left) {
    if (engine == nullptr) {
        return 0.0f;
    }
    chips::IModule* module = engine->graph.node(node);
    auto* mixer = dynamic_cast<chips::MixerModule*>(module);
    if (mixer == nullptr) {
        return 0.0f;
    }
    return mixer->masterPeak(is_left);
}

}  // extern "C"
