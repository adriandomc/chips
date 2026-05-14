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

void appendChannelSpec(std::vector<std::string>& names, std::vector<ParamSpec>& specs, int channel,
                       MixerModule::ParamKind kind, const char* suffix, const char* unit, float minValue,
                       float maxValue, float defaultValue) {
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

MixerModule::MixerModule(int numChannels)
    : numChannels_(std::max(1, std::min(kMaxChannels, numChannels))),
      channelPeak_(static_cast<size_t>(numChannels_) * 2) {
    channels_.assign(static_cast<size_t>(numChannels_), Channel{});
    for (auto& peak : channelPeak_) {
        peak.store(0.0f, std::memory_order_relaxed);
    }

    const size_t totalSpecs = static_cast<size_t>(numChannels_) * 3;
    paramNameStorage_.reserve(totalSpecs);
    paramSpecs_.reserve(totalSpecs);

    for (int channel = 0; channel < numChannels_; ++channel) {
        appendChannelSpec(paramNameStorage_, paramSpecs_, channel, Gain, "gain", "", 0.0f, 2.0f, 1.0f);
        appendChannelSpec(paramNameStorage_, paramSpecs_, channel, Pan, "pan", "", -1.0f, 1.0f, 0.0f);
        appendChannelSpec(paramNameStorage_, paramSpecs_, channel, Mute, "mute", "", 0.0f, 1.0f, 0.0f);
    }
}

float MixerModule::channelPeak(int channel, bool isLeft) const {
    if (channel < 0 || channel >= numChannels_) {
        return 0.0f;
    }
    const size_t idx = static_cast<size_t>(channel) * 2 + (isLeft ? 0 : 1);
    return channelPeak_[idx].load(std::memory_order_relaxed);
}

float MixerModule::masterPeak(bool isLeft) const {
    return (isLeft ? masterPeakL_ : masterPeakR_).load(std::memory_order_relaxed);
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
        const size_t peakIdx = static_cast<size_t>(channelIdx) * 2;
        // Decay del peak retenido (incluso si el canal está muted).
        const float decayedL = channelPeak_[peakIdx].load(std::memory_order_relaxed) * kPeakDecayPerBlock;
        const float decayedR = channelPeak_[peakIdx + 1].load(std::memory_order_relaxed) * kPeakDecayPerBlock;
        if (ch.muted) {
            channelPeak_[peakIdx].store(decayedL, std::memory_order_relaxed);
            channelPeak_[peakIdx + 1].store(decayedR, std::memory_order_relaxed);
            continue;
        }
        const float* inL = ctx.audioIn != nullptr ? ctx.audioIn[channelIdx * 2] : nullptr;
        const float* inR = ctx.audioIn != nullptr ? ctx.audioIn[channelIdx * 2 + 1] : nullptr;
        if (inL == nullptr || inR == nullptr) {
            channelPeak_[peakIdx].store(decayedL, std::memory_order_relaxed);
            channelPeak_[peakIdx + 1].store(decayedR, std::memory_order_relaxed);
            continue;
        }
        const float panNorm = (ch.pan + 1.0f) * 0.5f;
        const float gainL = ch.gain * std::cos(panNorm * static_cast<float>(M_PI_2));
        const float gainR = ch.gain * std::sin(panNorm * static_cast<float>(M_PI_2));
        float blockPeakL = 0.0f;
        float blockPeakR = 0.0f;
        for (int i = 0; i < ctx.frames; ++i) {
            const float wetL = inL[i] * gainL;
            const float wetR = inR[i] * gainR;
            outL[i] += wetL;
            outR[i] += wetR;
            const float absL = std::fabs(wetL);
            const float absR = std::fabs(wetR);
            if (absL > blockPeakL) blockPeakL = absL;
            if (absR > blockPeakR) blockPeakR = absR;
        }
        channelPeak_[peakIdx].store(std::max(decayedL, blockPeakL), std::memory_order_relaxed);
        channelPeak_[peakIdx + 1].store(std::max(decayedR, blockPeakR), std::memory_order_relaxed);
    }

    // Soft-clip limiter en master out: tanh suave aplicado tras la suma para
    // que sumar varios canales sin headroom no produzca clipping duro. Ceiling
    // ~ -0.5 dBFS — el output queda dentro de [-0.94, 0.94] aprox.
    constexpr float kLimitCeiling = 0.94f;
    for (int i = 0; i < ctx.frames; ++i) {
        outL[i] = std::tanh(outL[i]) * kLimitCeiling;
        outR[i] = std::tanh(outR[i]) * kLimitCeiling;
    }

    // Master peak (post-limiter, así el meter refleja la señal real que sale).
    float masterDecayedL = masterPeakL_.load(std::memory_order_relaxed) * kPeakDecayPerBlock;
    float masterDecayedR = masterPeakR_.load(std::memory_order_relaxed) * kPeakDecayPerBlock;
    float masterBlockL = 0.0f;
    float masterBlockR = 0.0f;
    for (int i = 0; i < ctx.frames; ++i) {
        const float aL = std::fabs(outL[i]);
        const float aR = std::fabs(outR[i]);
        if (aL > masterBlockL) masterBlockL = aL;
        if (aR > masterBlockR) masterBlockR = aR;
    }
    masterPeakL_.store(std::max(masterDecayedL, masterBlockL), std::memory_order_relaxed);
    masterPeakR_.store(std::max(masterDecayedR, masterBlockR), std::memory_order_relaxed);
}

}  // namespace chips
