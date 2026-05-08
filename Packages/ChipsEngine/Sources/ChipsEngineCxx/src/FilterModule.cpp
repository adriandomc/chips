// FilterModule.cpp

#include "FilterModule.hpp"

#include "ModuleRegistry.hpp"

#include <algorithm>
#include <cmath>

namespace chips {

namespace {
constexpr double kTwoPi = 6.28318530717958647692;

const ParamSpec kFilterParamSpecs[] = {
    {FilterModule::ParamMode, "mode", "", 0.0f, 2.0f, 0.0f},
    {FilterModule::ParamCutoff, "cutoff", "Hz", 20.0f, 18000.0f, 2000.0f},
    {FilterModule::ParamResonance, "resonance", "", 0.5f, 18.0f, 0.707f},
};

[[gnu::used]] const bool kRegistered =
    ModuleRegistry::instance().register_("filter", [] { return std::unique_ptr<IModule>(new FilterModule()); });
}  // namespace

void FilterModule::forceLink() {}

int FilterModule::numParameters() const {
    return static_cast<int>(sizeof(kFilterParamSpecs) / sizeof(kFilterParamSpecs[0]));
}

ParamSpec FilterModule::parameterAt(int index) const {
    if (index < 0 || index >= numParameters()) {
        return ParamSpec{};
    }
    return kFilterParamSpecs[index];
}

FilterModule::FilterModule() = default;

void FilterModule::prepare(double sampleRate, int /*maxFrames*/) {
    sampleRate_ = sampleRate > 0 ? sampleRate : 48000.0;
    recompute();
    reset();
}

void FilterModule::reset() {
    zL1_ = zL2_ = zR1_ = zR2_ = 0.0f;
}

void FilterModule::handleParameterChange(uint32_t paramId, float value) {
    switch (paramId) {
    case ParamMode:
        mode_ = std::max(0, std::min(2, static_cast<int>(std::round(value))));
        break;
    case ParamCutoff:
        cutoffHz_ = std::max(20.0f, std::min(18000.0f, value));
        break;
    case ParamResonance:
        q_ = std::max(0.5f, std::min(18.0f, value));
        break;
    }
    recompute();
}

void FilterModule::recompute() {
    const double w0 = kTwoPi * static_cast<double>(cutoffHz_) / std::max(1.0, sampleRate_);
    const double cosw0 = std::cos(w0);
    const double sinw0 = std::sin(w0);
    const double alpha = sinw0 / (2.0 * std::max(0.01, static_cast<double>(q_)));

    double b0 = 0, b1Local = 0, b2 = 0;
    double a0 = 1.0 + alpha, a1 = -2.0 * cosw0, a2 = 1.0 - alpha;
    switch (mode_) {
    case ModeLowPass:
        b0 = (1.0 - cosw0) / 2.0;
        b1Local = 1.0 - cosw0;
        b2 = (1.0 - cosw0) / 2.0;
        break;
    case ModeHighPass:
        b0 = (1.0 + cosw0) / 2.0;
        b1Local = -(1.0 + cosw0);
        b2 = (1.0 + cosw0) / 2.0;
        break;
    case ModeBandPass:
        b0 = alpha;
        b1Local = 0.0;
        b2 = -alpha;
        break;
    }
    a0_ = static_cast<float>(b0 / a0);
    a1_ = static_cast<float>(b1Local / a0);
    a2_ = static_cast<float>(b2 / a0);
    b1_ = static_cast<float>(a1 / a0);
    b2_ = static_cast<float>(a2 / a0);
}

void FilterModule::process(const ProcessContext& ctx) {
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
    for (int i = 0; i < ctx.frames; ++i) {
        // L
        const float xL = inL[i];
        const float yL = a0_ * xL + zL1_;
        zL1_ = a1_ * xL - b1_ * yL + zL2_;
        zL2_ = a2_ * xL - b2_ * yL;
        outL[i] = yL;
        // R
        const float xR = inR[i];
        const float yR = a0_ * xR + zR1_;
        zR1_ = a1_ * xR - b1_ * yR + zR2_;
        zR2_ = a2_ * xR - b2_ * yR;
        outR[i] = yR;
    }
}

}  // namespace chips
