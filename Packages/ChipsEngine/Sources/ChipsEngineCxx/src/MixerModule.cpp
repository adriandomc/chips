// MixerModule.cpp

#include "MixerModule.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace chips {

MixerModule::MixerModule() = default;

void MixerModule::prepare(double /*sampleRate*/, int /*maxFrames*/) {
    reset();
}

void MixerModule::reset() {
    for (auto& ch : channels_) {
        ch.gain = 1.0f;
        ch.pan = 0.0f;
        ch.muted = false;
    }
}

void MixerModule::handleParameterChange(uint32_t paramId, float value) {
    const int channel = static_cast<int>(paramId >> 8);
    const ParamKind kind = static_cast<ParamKind>(paramId & 0xFF);
    if (channel < 0 || channel >= kMaxChannels) {
        return;
    }
    Channel& ch = channels_[static_cast<size_t>(channel)];
    switch (kind) {
    case Gain:
        ch.gain = std::max(0.0f, std::min(2.0f, value));
        break;
    case Pan:
        ch.pan = std::max(-1.0f, std::min(1.0f, value));
        break;
    case Mute:
        ch.muted = value > 0.5f;
        break;
    }
}

void MixerModule::process(const ProcessContext& ctx) {
    if (ctx.numAudioOut < 2 || ctx.audioOut == nullptr || ctx.frames <= 0) {
        return;
    }
    float* outL = ctx.audioOut[0];
    float* outR = ctx.audioOut[1];
    if (outL == nullptr || outR == nullptr) {
        return;
    }
    std::memset(outL, 0, static_cast<size_t>(ctx.frames) * sizeof(float));
    std::memset(outR, 0, static_cast<size_t>(ctx.frames) * sizeof(float));

    const int totalChannels = std::min(kMaxChannels, ctx.numAudioIn / 2);
    for (int channelIdx = 0; channelIdx < totalChannels; ++channelIdx) {
        const Channel& ch = channels_[static_cast<size_t>(channelIdx)];
        if (ch.muted) {
            continue;
        }
        const float* inL = ctx.audioIn != nullptr ? ctx.audioIn[channelIdx * 2] : nullptr;
        const float* inR = ctx.audioIn != nullptr ? ctx.audioIn[channelIdx * 2 + 1] : nullptr;
        if (inL == nullptr || inR == nullptr) {
            continue;
        }
        // Ley de pan equal-power: pan -1 = full L, +1 = full R.
        const float panNorm = (ch.pan + 1.0f) * 0.5f;
        const float gainL = ch.gain * std::cos(panNorm * static_cast<float>(M_PI_2));
        const float gainR = ch.gain * std::sin(panNorm * static_cast<float>(M_PI_2));
        for (int i = 0; i < ctx.frames; ++i) {
            outL[i] += inL[i] * gainL;
            outR[i] += inR[i] * gainR;
        }
    }
}

}  // namespace chips
