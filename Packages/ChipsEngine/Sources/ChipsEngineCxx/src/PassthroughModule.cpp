// PassthroughModule.cpp

#include "PassthroughModule.hpp"

#include "ModuleRegistry.hpp"

#include <cstring>

namespace chips {

namespace {
[[gnu::used]] const bool kRegistered = ModuleRegistry::instance().register_(
    "passthrough", [] { return std::unique_ptr<IModule>(new PassthroughModule(2)); });
}  // namespace

void PassthroughModule::forceLink() {}

void PassthroughModule::process(const ProcessContext& ctx) {
    const int chans = ctx.numAudioIn < ctx.numAudioOut ? ctx.numAudioIn : ctx.numAudioOut;
    for (int c = 0; c < chans; ++c) {
        const float* in = ctx.audioIn[c];
        float* out = ctx.audioOut[c];
        if (in == nullptr || out == nullptr) {
            continue;
        }
        std::memcpy(out, in, static_cast<size_t>(ctx.frames) * sizeof(float));
    }
}

}  // namespace chips
