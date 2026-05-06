// PassthroughModule.cpp

#include "PassthroughModule.hpp"

#include <cstring>

namespace chips {

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
