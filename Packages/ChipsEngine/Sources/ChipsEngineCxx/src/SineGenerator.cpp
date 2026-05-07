// SineGenerator.cpp — implementación.

#include "SineGenerator.hpp"

#include "ModuleRegistry.hpp"

#include <cmath>
#include <cstring>

namespace chips {

namespace {
constexpr double kTwoPi = 6.28318530717958647692;

const ParamSpec kSineParamSpecs[] = {
    {SineGenerator::ParamFrequency, "frequency", "Hz", 20.0f, 20000.0f, 440.0f},
    {SineGenerator::ParamEnabled, "enabled", "", 0.0f, 1.0f, 0.0f},
    {SineGenerator::ParamAmplitude, "amplitude", "", 0.0f, 1.0f, 0.25f},
};

[[gnu::used]] const bool kRegistered =
    ModuleRegistry::instance().register_("sine", [] { return std::unique_ptr<IModule>(new SineGenerator()); });
}  // namespace

void SineGenerator::forceLink() {}

const char* SineGenerator::typeId() const {
    return "sine";
}

int SineGenerator::numParameters() const {
    return static_cast<int>(sizeof(kSineParamSpecs) / sizeof(kSineParamSpecs[0]));
}

ParamSpec SineGenerator::parameterAt(int index) const {
    if (index < 0 || index >= numParameters()) {
        return ParamSpec{};
    }
    return kSineParamSpecs[index];
}

void SineGenerator::prepare(double sampleRate, int /*maxFrames*/) {
    sampleRate_ = sampleRate > 0.0 ? sampleRate : 48000.0;
    phase_ = 0.0;
}

void SineGenerator::reset() {
    phase_ = 0.0;
}

void SineGenerator::setFrequency(float hz) {
    if (hz < 0.0f) {
        hz = 0.0f;
    }
    frequency_.store(hz, std::memory_order_relaxed);
}

void SineGenerator::setEnabled(bool enabled) {
    enabled_.store(enabled, std::memory_order_relaxed);
}
bool SineGenerator::isEnabled() const {
    return enabled_.load(std::memory_order_relaxed);
}
float SineGenerator::frequency() const {
    return frequency_.load(std::memory_order_relaxed);
}

void SineGenerator::handleParameterChange(uint32_t paramId, float value) {
    switch (paramId) {
    case ParamFrequency:
        setFrequency(value);
        break;
    case ParamEnabled:
        setEnabled(value > 0.5f);
        break;
    case ParamAmplitude:
        amplitude_.store(value, std::memory_order_relaxed);
        break;
    default:
        break;
    }
}

void SineGenerator::process(const ProcessContext& ctx) {
    if (ctx.numAudioOut < 2 || ctx.audioOut == nullptr || ctx.frames <= 0) {
        return;
    }
    float* outL = ctx.audioOut[0];
    float* outR = ctx.audioOut[1];
    if (outL == nullptr || outR == nullptr) {
        return;
    }

    if (!enabled_.load(std::memory_order_relaxed)) {
        std::memset(outL, 0, static_cast<size_t>(ctx.frames) * sizeof(float));
        std::memset(outR, 0, static_cast<size_t>(ctx.frames) * sizeof(float));
        return;
    }

    const float freq = frequency_.load(std::memory_order_relaxed);
    const float amp = amplitude_.load(std::memory_order_relaxed);
    const double phaseInc = (kTwoPi * static_cast<double>(freq)) / sampleRate_;
    double phase = phase_;
    for (int i = 0; i < ctx.frames; ++i) {
        const float sample = static_cast<float>(std::sin(phase)) * amp;
        outL[i] = sample;
        outR[i] = sample;
        phase += phaseInc;
        if (phase >= kTwoPi) {
            phase -= kTwoPi;
        }
    }
    phase_ = phase;
}

}  // namespace chips
