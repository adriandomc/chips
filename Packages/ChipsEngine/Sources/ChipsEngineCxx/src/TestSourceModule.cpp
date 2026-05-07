// TestSourceModule.cpp

#include "TestSourceModule.hpp"

#include "ModuleRegistry.hpp"

namespace chips {

namespace {
[[gnu::used]] const bool kRegistered = ModuleRegistry::instance().register_(
    "test_source", [] { return std::unique_ptr<IModule>(new TestSourceModule(64, 1)); });
}  // namespace

void TestSourceModule::forceLink() {}

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
