// MixerModule.cpp

#include "MixerModule.hpp"

#include "ModuleRegistry.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace chips {

namespace {
[[gnu::used]] const bool kRegistered =
    ModuleRegistry::instance().register_("mixer", [] { return std::unique_ptr<IModule>(new MixerModule()); });

void appendChannelSpec(std::vector<std::string>& names,
                       std::vector<ParamSpec>& specs,
                       int channel,
                       MixerModule::ParamKind kind,
                       const char* suffix,
                       const char* unit,
                       float minValue,
                       float maxValue,
                       float defaultValue) {
    names.emplace_back("ch" + std::to_string(channel) + "_" + suffix);
    specs.push_back(ParamSpec{
        MixerModule::paramId(channel, kind),
        names.back().c_str(),
        unit,
        minValue,
        maxValue,
        defaultValue,
    });
}
}  // namespace

void MixerModule::forceLink() {}

MixerModule::MixerModule(int numChannels) :
    numChannels_(std::max(1, std::min(kMaxChannels, numChannels))) {
    channels_.assign(static_cast<size_t>(numChannels_), Channel{});

    const size_t totalSpecs = static_cast<size_t>(numChannels_) * 3;
    paramNameStorage_.reserve(totalSpecs);
    paramSpecs_.reserve(totalSpecs);

    for (int channel = 0; channel < numChannels_; ++channel) {
        appendChannelSpec(paramNameStorage_, paramSpecs_, channel, Gain, "gain", "", 0.0f, 2.0f, 1.0f);
        appendChannelSpec(paramNameStorage_, paramSpecs_, channel, Pan, "pan", "", -1.0f, 1.0f, 0.0f);
        appendChannelSpec(paramNameStorage_, paramSpecs_, channel, Mute, "mute", "", 0.0f, 1.0f, 0.0f);
    }
}

ParamSpec MixerModule::parameterAt(int index) const {
    if (index < 0 || index >= static_cast<int>(paramSpecs_.size())) {
        return ParamSpec{};
    }
    return paramSpecs_[static_cast<size_t>(index)];
}

void MixerModule::prepare(double /*sampleRate*/, int /*maxFrames*/) {
    reset();
}

void MixerModule::reset() {
    for (auto& channel : channels_) {
        channel.gain = 1.0f;
        channel.pan = 0.0f;
        channel.muted = false;
    }
}

void MixerModule::handleParameterChange(uint32_t paramId, float value) {
    const int channel = static_cast<int>(paramId >> 8);
    const ParamKind kind = static_cast<ParamKind>(paramId & 0xFF);
    if (channel < 0 || channel >= numChannels_) {
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

    const int totalChannels = std::min(numChannels_, ctx.numAudioIn / 2);
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
