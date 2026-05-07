// DelayModule.cpp

#include "DelayModule.hpp"

#include "ModuleRegistry.hpp"

#include <algorithm>
#include <cstring>

namespace chips {

namespace {
const ParamSpec kDelayParamSpecs[] = {
    {DelayModule::ParamTime, "time", "s", 0.001f, 2.0f, 0.35f},
    {DelayModule::ParamFeedback, "feedback", "", 0.0f, 0.95f, 0.35f},
    {DelayModule::ParamWet, "wet", "", 0.0f, 1.0f, 0.20f},
};

[[gnu::used]] const bool kRegistered =
    ModuleRegistry::instance().register_("delay", [] { return std::unique_ptr<IModule>(new DelayModule()); });
}  // namespace

void DelayModule::forceLink() {}

int DelayModule::numParameters() const {
    return static_cast<int>(sizeof(kDelayParamSpecs) / sizeof(kDelayParamSpecs[0]));
}

ParamSpec DelayModule::parameterAt(int index) const {
    if (index < 0 || index >= numParameters()) {
        return ParamSpec{};
    }
    return kDelayParamSpecs[index];
}

void DelayModule::prepare(double sampleRate, int /*maxFrames*/) {
    sampleRate_ = sampleRate > 0 ? sampleRate : 48000.0;
    bufferSize_ = static_cast<int>(sampleRate_ * 2.0);  // hasta 2 s
    bufferL_.assign(static_cast<size_t>(bufferSize_), 0.0f);
    bufferR_.assign(static_cast<size_t>(bufferSize_), 0.0f);
    writeIdx_ = 0;
}

void DelayModule::reset() {
    std::fill(bufferL_.begin(), bufferL_.end(), 0.0f);
    std::fill(bufferR_.begin(), bufferR_.end(), 0.0f);
    writeIdx_ = 0;
}

void DelayModule::handleParameterChange(uint32_t paramId, float value) {
    switch (paramId) {
    case ParamTime:
        timeSeconds_ = std::max(0.001f, std::min(2.0f, value));
        break;
    case ParamFeedback:
        feedback_ = std::max(0.0f, std::min(0.95f, value));
        break;
    case ParamWet:
        wet_ = std::max(0.0f, std::min(1.0f, value));
        break;
    default:
        break;
    }
}

void DelayModule::process(const ProcessContext& ctx) {
    if (ctx.numAudioIn < 2 || ctx.numAudioOut < 2 || ctx.frames <= 0 || bufferSize_ <= 0) {
        return;
    }
    const float* inL = ctx.audioIn[0];
    const float* inR = ctx.audioIn[1];
    float* outL = ctx.audioOut[0];
    float* outR = ctx.audioOut[1];
    if (inL == nullptr || inR == nullptr || outL == nullptr || outR == nullptr) {
        return;
    }

    int delaySamples = static_cast<int>(timeSeconds_ * static_cast<float>(sampleRate_));
    delaySamples = std::max(1, std::min(bufferSize_ - 1, delaySamples));

    for (int i = 0; i < ctx.frames; ++i) {
        int readIdx = writeIdx_ - delaySamples;
        if (readIdx < 0) {
            readIdx += bufferSize_;
        }
        const float delayedL = bufferL_[static_cast<size_t>(readIdx)];
        const float delayedR = bufferR_[static_cast<size_t>(readIdx)];

        // Ping-pong: el feedback de L va al buffer R y viceversa.
        bufferL_[static_cast<size_t>(writeIdx_)] = inL[i] + delayedR * feedback_;
        bufferR_[static_cast<size_t>(writeIdx_)] = inR[i] + delayedL * feedback_;

        outL[i] = inL[i] * (1.0f - wet_) + delayedL * wet_;
        outR[i] = inR[i] * (1.0f - wet_) + delayedR * wet_;

        writeIdx_++;
        if (writeIdx_ >= bufferSize_) {
            writeIdx_ = 0;
        }
    }
}

}  // namespace chips
