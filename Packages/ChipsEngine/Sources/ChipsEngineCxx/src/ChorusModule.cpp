// ChorusModule.cpp

#include "ChorusModule.hpp"

#include "ModuleRegistry.hpp"

#include <algorithm>
#include <cmath>

namespace chips {

namespace {
constexpr double kTwoPi = 6.28318530717958647692;

const ParamSpec kChorusParamSpecs[] = {
    {ChorusModule::ParamRate, "rate", "Hz", 0.05f, 5.0f, 0.6f},
    {ChorusModule::ParamDepth, "depth", "", 0.0f, 1.0f, 0.5f},
    {ChorusModule::ParamMix, "mix", "", 0.0f, 1.0f, 0.5f},
};

[[gnu::used]] const bool kRegistered =
    ModuleRegistry::instance().register_("chorus", [] { return std::unique_ptr<IModule>(new ChorusModule()); });
}  // namespace

void ChorusModule::forceLink() {}

int ChorusModule::numParameters() const {
    return static_cast<int>(sizeof(kChorusParamSpecs) / sizeof(kChorusParamSpecs[0]));
}

ParamSpec ChorusModule::parameterAt(int index) const {
    if (index < 0 || index >= numParameters()) {
        return ParamSpec{};
    }
    return kChorusParamSpecs[index];
}

ChorusModule::ChorusModule() = default;

void ChorusModule::prepare(double sampleRate, int /*maxFrames*/) {
    sampleRate_ = sampleRate > 0 ? sampleRate : 48000.0;
    // Buffer suficiente para baseDelay + depth max.
    const int sizeFrames = static_cast<int>(sampleRate_ * 0.05) + 1;  // 50ms cubre todo
    bufferL_.assign(static_cast<size_t>(sizeFrames), 0.0f);
    bufferR_.assign(static_cast<size_t>(sizeFrames), 0.0f);
    reset();
}

void ChorusModule::reset() {
    std::fill(bufferL_.begin(), bufferL_.end(), 0.0f);
    std::fill(bufferR_.begin(), bufferR_.end(), 0.0f);
    writeIndex_ = 0;
    phase_ = 0.0;
}

void ChorusModule::handleParameterChange(uint32_t paramId, float value) {
    switch (paramId) {
    case ParamRate: rateHz_ = std::max(0.05f, std::min(5.0f, value)); break;
    case ParamDepth: depth_ = std::max(0.0f, std::min(1.0f, value)); break;
    case ParamMix: mix_ = std::max(0.0f, std::min(1.0f, value)); break;
    }
}

void ChorusModule::process(const ProcessContext& ctx) {
    if (ctx.numAudioOut < 2 || ctx.audioOut == nullptr || ctx.audioIn == nullptr || ctx.numAudioIn < 2) {
        return;
    }
    float* outL = ctx.audioOut[0];
    float* outR = ctx.audioOut[1];
    const float* inL = ctx.audioIn[0];
    const float* inR = ctx.audioIn[1];
    if (outL == nullptr || outR == nullptr || inL == nullptr || inR == nullptr) {
        return;
    }
    if (bufferL_.empty() || bufferR_.empty()) {
        return;
    }
    const int bufSize = static_cast<int>(bufferL_.size());
    const double phaseInc = static_cast<double>(rateHz_) / sampleRate_;
    const float baseSamples = kBaseDelayMs * 0.001f * static_cast<float>(sampleRate_);
    const float depthSamples = kDepthMs * 0.001f * static_cast<float>(sampleRate_) * depth_;

    for (int i = 0; i < ctx.frames; ++i) {
        // Escribir input al buffer.
        bufferL_[static_cast<size_t>(writeIndex_)] = inL[i];
        bufferR_[static_cast<size_t>(writeIndex_)] = inR[i];

        // LFO L y R (en cuadratura para stereo width).
        const float lfoL = std::sin(static_cast<float>(kTwoPi * phase_));
        const float lfoR = std::sin(static_cast<float>(kTwoPi * (phase_ + 0.25)));
        const float delayL = baseSamples + depthSamples * lfoL;
        const float delayR = baseSamples + depthSamples * lfoR;

        const auto readSample = [&](const std::vector<float>& buf, float delaySamples) {
            float readPos = static_cast<float>(writeIndex_) - delaySamples;
            while (readPos < 0) readPos += static_cast<float>(bufSize);
            const int idxLow = static_cast<int>(std::floor(readPos)) % bufSize;
            const int idxHigh = (idxLow + 1) % bufSize;
            const float frac = readPos - std::floor(readPos);
            return buf[static_cast<size_t>(idxLow)] * (1.0f - frac) + buf[static_cast<size_t>(idxHigh)] * frac;
        };
        const float wetL = readSample(bufferL_, delayL);
        const float wetR = readSample(bufferR_, delayR);

        outL[i] = inL[i] * (1.0f - mix_) + wetL * mix_;
        outR[i] = inR[i] * (1.0f - mix_) + wetR * mix_;

        writeIndex_ = (writeIndex_ + 1) % bufSize;
        phase_ += phaseInc;
        if (phase_ >= 1.0) phase_ -= 1.0;
    }
}

}  // namespace chips
