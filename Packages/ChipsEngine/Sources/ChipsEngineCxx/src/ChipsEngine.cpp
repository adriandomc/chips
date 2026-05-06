// ChipsEngine.cpp — implementación inicial (M0/M1 placeholder).
// Será sustituida por el grafo real en M1.

#include "ChipsEngine/ChipsEngine.h"

#include <cstdlib>
#include <cstring>

namespace {
constexpr const char* kVersion = "0.0.1-m0";
}  // namespace

struct ChipsEngineHandle {
    double sampleRate;
    int maxFrames;
};

extern "C" {

ChipsEngineHandle* chips_engine_create(double sample_rate, int max_frames) {
    if (sample_rate <= 0.0 || max_frames <= 0) {
        return nullptr;
    }
    auto* engine = static_cast<ChipsEngineHandle*>(std::malloc(sizeof(ChipsEngineHandle)));
    if (engine == nullptr) {
        return nullptr;
    }
    engine->sampleRate = sample_rate;
    engine->maxFrames = max_frames;
    return engine;
}

void chips_engine_destroy(ChipsEngineHandle* engine) {
    std::free(engine);
}

void chips_engine_render(ChipsEngineHandle* engine, float* interleaved_stereo_out, int frames) {
    (void)engine;
    if (interleaved_stereo_out == nullptr || frames <= 0) {
        return;
    }
    // M0: silencio. El grafo real se implementa en M1.
    std::memset(interleaved_stereo_out, 0, static_cast<size_t>(frames) * 2 * sizeof(float));
}

const char* chips_engine_version(void) {
    return kVersion;
}

}  // extern "C"
