// CompressorModule.cpp

#include "CompressorModule.hpp"

#include "ModuleRegistry.hpp"

#include <algorithm>
#include <cmath>

namespace chips {

namespace {
const ParamSpec kCompressorParamSpecs[] = {
    {CompressorModule::ParamThreshold, "threshold", "", 0.01f, 1.0f, 0.5f},
    {CompressorModule::ParamRatio, "ratio", "", 1.0f, 20.0f, 4.0f},
    {CompressorModule::ParamAttack, "attack", "ms", 0.1f, 200.0f, 5.0f},
    {CompressorModule::ParamRelease, "release", "ms", 10.0f, 1000.0f, 100.0f},
    {CompressorModule::ParamMakeup, "makeup", "", 1.0f, 8.0f, 1.0f},
};

[[gnu::used]] const bool kRegistered =
    ModuleRegistry::instance().register_("compressor", [] { return std::unique_ptr<IModule>(new CompressorModule()); });
}  // namespace

void CompressorModule::forceLink() {}

int CompressorModule::numParameters() const {
    return static_cast<int>(sizeof(kCompressorParamSpecs) / sizeof(kCompressorParamSpecs[0]));
}

ParamSpec CompressorModule::parameterAt(int index) const {
    if (index < 0 || index >= numParameters()) {
        return ParamSpec{};
    }
    return kCompressorParamSpecs[index];
}

CompressorModule::CompressorModule() = default;

void CompressorModule::prepare(double sampleRate, int /*maxFrames*/) {
    sampleRate_ = sampleRate > 0 ? sampleRate : 48000.0;
    recomputeCoefficients();
    reset();
}

void CompressorModule::reset() {
    envelope_ = 0.0f;
}

void CompressorModule::handleParameterChange(uint32_t paramId, float value) {
    switch (paramId) {
    case ParamThreshold:
        threshold_ = std::max(0.01f, std::min(1.0f, value));
        break;
    case ParamRatio:
        ratio_ = std::max(1.0f, std::min(20.0f, value));
        break;
    case ParamAttack:
        attackMs_ = std::max(0.1f, std::min(200.0f, value));
        recomputeCoefficients();
        break;
    case ParamRelease:
        releaseMs_ = std::max(10.0f, std::min(1000.0f, value));
        recomputeCoefficients();
        break;
    case ParamMakeup:
        makeup_ = std::max(1.0f, std::min(8.0f, value));
        break;
    }
}

void CompressorModule::recomputeCoefficients() {
    // Coeficientes one-pole: a = exp(-1 / (tauSamples)) donde tau = ms * sampleRate / 1000.
    const double attackSamples = std::max(1.0, static_cast<double>(attackMs_) * sampleRate_ / 1000.0);
    const double releaseSamples = std::max(1.0, static_cast<double>(releaseMs_) * sampleRate_ / 1000.0);
    attackCoeff_ = static_cast<float>(std::exp(-1.0 / attackSamples));
    releaseCoeff_ = static_cast<float>(std::exp(-1.0 / releaseSamples));
}

void CompressorModule::process(const ProcessContext& ctx) {
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
        // Detector: max(|L|, |R|) — peak stereo.
        const float input = std::max(std::fabs(inL[i]), std::fabs(inR[i]));
        // One-pole envelope follower.
        const float coeff = input > envelope_ ? attackCoeff_ : releaseCoeff_;
        envelope_ = coeff * envelope_ + (1.0f - coeff) * input;

        // Cálculo de gain reduction: si envelope > threshold, comprimimos linealmente.
        float gain = 1.0f;
        if (envelope_ > threshold_) {
            const float over = envelope_ - threshold_;
            // ratio: por cada 1 sobre threshold, dejamos solo 1/ratio.
            const float compressed = over / ratio_;
            const float targetEnv = threshold_ + compressed;
            gain = targetEnv / envelope_;
        }
        outL[i] = inL[i] * gain * makeup_;
        outR[i] = inR[i] * gain * makeup_;
    }
}

}  // namespace chips
