// TestSourceModule.cpp

#include "TestSourceModule.hpp"

namespace chips {

void TestSourceModule::process(const ProcessContext& ctx) {
    if (ctx.numAudioOut < channels_ || ctx.audioOut == nullptr) {
        return;
    }
    for (int i = 0; i < ctx.frames; ++i) {
        const float v = (static_cast<float>(phase_) / static_cast<float>(period_)) * 2.0f - 1.0f;
        for (int c = 0; c < channels_; ++c) {
            float* out = ctx.audioOut[c];
            if (out != nullptr) {
                out[i] = v;
            }
        }
        phase_ = (phase_ + 1) % period_;
    }
}

}  // namespace chips
