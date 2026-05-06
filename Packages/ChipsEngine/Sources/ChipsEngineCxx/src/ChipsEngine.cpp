// ChipsEngine.cpp — implementación de la C ABI sobre el grafo C++.

#include "ChipsEngine/ChipsEngine.h"

#include "DspLoadTracker.hpp"
#include "SineGenerator.hpp"

#include <new>

namespace {
constexpr const char* kVersion = "0.1.0-m1";
}  // namespace

struct ChipsEngineHandle {
    double sampleRate;
    int maxFrames;
    chips::SineGenerator sine;
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
    engine->sine.prepare(sample_rate);
    return engine;
}

void chips_engine_destroy(ChipsEngineHandle* engine) {
    delete engine;
}

void chips_engine_render(ChipsEngineHandle* engine, float* interleaved_stereo_out, int frames) {
    if (engine == nullptr || interleaved_stereo_out == nullptr || frames <= 0) {
        return;
    }
    const auto t0 = engine->loadTracker.begin();
    engine->sine.process(interleaved_stereo_out, frames);
    engine->loadTracker.end(t0, frames, engine->sampleRate);
}

const char* chips_engine_version(void) {
    return kVersion;
}

void chips_engine_set_sine_frequency(ChipsEngineHandle* engine, float hz) {
    if (engine == nullptr) {
        return;
    }
    engine->sine.setFrequency(hz);
}

void chips_engine_set_sine_enabled(ChipsEngineHandle* engine, bool enabled) {
    if (engine == nullptr) {
        return;
    }
    engine->sine.setEnabled(enabled);
}

bool chips_engine_is_sine_enabled(const ChipsEngineHandle* engine) {
    if (engine == nullptr) {
        return false;
    }
    return engine->sine.isEnabled();
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

}  // extern "C"
