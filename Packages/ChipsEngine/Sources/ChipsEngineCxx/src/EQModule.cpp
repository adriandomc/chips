// EQModule.cpp

#include "EQModule.hpp"

#include "ModuleRegistry.hpp"

#include <algorithm>
#include <cmath>

namespace chips {

namespace {
constexpr double kTwoPi = 6.28318530717958647692;

const ParamSpec kEQParamSpecs[] = {
    {EQModule::ParamLowGain, "lowGain", "dB", -18.0f, 18.0f, 0.0f},
    {EQModule::ParamLowFreq, "lowFreq", "Hz", 50.0f, 500.0f, 200.0f},
    {EQModule::ParamMidGain, "midGain", "dB", -18.0f, 18.0f, 0.0f},
    {EQModule::ParamMidFreq, "midFreq", "Hz", 200.0f, 5000.0f, 1000.0f},
    {EQModule::ParamMidQ, "midQ", "", 0.5f, 8.0f, 1.0f},
    {EQModule::ParamHighGain, "highGain", "dB", -18.0f, 18.0f, 0.0f},
    {EQModule::ParamHighFreq, "highFreq", "Hz", 2000.0f, 16000.0f, 6000.0f},
};

[[gnu::used]] const bool kRegistered =
    ModuleRegistry::instance().register_("eq", [] { return std::unique_ptr<IModule>(new EQModule()); });
}  // namespace

void EQModule::forceLink() {}

int EQModule::numParameters() const {
    return static_cast<int>(sizeof(kEQParamSpecs) / sizeof(kEQParamSpecs[0]));
}

ParamSpec EQModule::parameterAt(int index) const {
    if (index < 0 || index >= numParameters()) {
        return ParamSpec{};
    }
    return kEQParamSpecs[index];
}

EQModule::EQModule() = default;

void EQModule::prepare(double sampleRate, int /*maxFrames*/) {
    sampleRate_ = sampleRate > 0 ? sampleRate : 48000.0;
    recomputeAll();
    reset();
}

void EQModule::reset() {
    low_.reset();
    mid_.reset();
    high_.reset();
}

void EQModule::handleParameterChange(uint32_t paramId, float value) {
    switch (paramId) {
    case ParamLowGain: lowGainDb_ = std::max(-18.0f, std::min(18.0f, value)); break;
    case ParamLowFreq: lowFreqHz_ = std::max(50.0f, std::min(500.0f, value)); break;
    case ParamMidGain: midGainDb_ = std::max(-18.0f, std::min(18.0f, value)); break;
    case ParamMidFreq: midFreqHz_ = std::max(200.0f, std::min(5000.0f, value)); break;
    case ParamMidQ: midQ_ = std::max(0.5f, std::min(8.0f, value)); break;
    case ParamHighGain: highGainDb_ = std::max(-18.0f, std::min(18.0f, value)); break;
    case ParamHighFreq: highFreqHz_ = std::max(2000.0f, std::min(16000.0f, value)); break;
    }
    recomputeAll();
}

void EQModule::recomputeAll() {
    computeLowShelf(low_, sampleRate_, lowFreqHz_, lowGainDb_);
    computePeaking(mid_, sampleRate_, midFreqHz_, midQ_, midGainDb_);
    computeHighShelf(high_, sampleRate_, highFreqHz_, highGainDb_);
}

void EQModule::computeLowShelf(Biquad& bq, double sampleRate, float freqHz, float gainDb) {
    const double A = std::pow(10.0, static_cast<double>(gainDb) / 40.0);
    const double w0 = kTwoPi * static_cast<double>(freqHz) / std::max(1.0, sampleRate);
    const double cosw0 = std::cos(w0);
    const double sinw0 = std::sin(w0);
    const double S = 1.0;
    const double alpha = sinw0 / 2.0 * std::sqrt((A + 1.0 / A) * (1.0 / S - 1.0) + 2.0);
    const double sqrtA = std::sqrt(A);

    const double b0 = A * ((A + 1.0) - (A - 1.0) * cosw0 + 2.0 * sqrtA * alpha);
    const double b1 = 2.0 * A * ((A - 1.0) - (A + 1.0) * cosw0);
    const double b2 = A * ((A + 1.0) - (A - 1.0) * cosw0 - 2.0 * sqrtA * alpha);
    const double a0 = (A + 1.0) + (A - 1.0) * cosw0 + 2.0 * sqrtA * alpha;
    const double a1 = -2.0 * ((A - 1.0) + (A + 1.0) * cosw0);
    const double a2 = (A + 1.0) + (A - 1.0) * cosw0 - 2.0 * sqrtA * alpha;

    bq.a0 = static_cast<float>(b0 / a0);
    bq.a1 = static_cast<float>(b1 / a0);
    bq.a2 = static_cast<float>(b2 / a0);
    bq.b1 = static_cast<float>(a1 / a0);
    bq.b2 = static_cast<float>(a2 / a0);
}

void EQModule::computeHighShelf(Biquad& bq, double sampleRate, float freqHz, float gainDb) {
    const double A = std::pow(10.0, static_cast<double>(gainDb) / 40.0);
    const double w0 = kTwoPi * static_cast<double>(freqHz) / std::max(1.0, sampleRate);
    const double cosw0 = std::cos(w0);
    const double sinw0 = std::sin(w0);
    const double S = 1.0;
    const double alpha = sinw0 / 2.0 * std::sqrt((A + 1.0 / A) * (1.0 / S - 1.0) + 2.0);
    const double sqrtA = std::sqrt(A);

    const double b0 = A * ((A + 1.0) + (A - 1.0) * cosw0 + 2.0 * sqrtA * alpha);
    const double b1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cosw0);
    const double b2 = A * ((A + 1.0) + (A - 1.0) * cosw0 - 2.0 * sqrtA * alpha);
    const double a0 = (A + 1.0) - (A - 1.0) * cosw0 + 2.0 * sqrtA * alpha;
    const double a1 = 2.0 * ((A - 1.0) - (A + 1.0) * cosw0);
    const double a2 = (A + 1.0) - (A - 1.0) * cosw0 - 2.0 * sqrtA * alpha;

    bq.a0 = static_cast<float>(b0 / a0);
    bq.a1 = static_cast<float>(b1 / a0);
    bq.a2 = static_cast<float>(b2 / a0);
    bq.b1 = static_cast<float>(a1 / a0);
    bq.b2 = static_cast<float>(a2 / a0);
}

void EQModule::computePeaking(Biquad& bq, double sampleRate, float freqHz, float q, float gainDb) {
    const double A = std::pow(10.0, static_cast<double>(gainDb) / 40.0);
    const double w0 = kTwoPi * static_cast<double>(freqHz) / std::max(1.0, sampleRate);
    const double cosw0 = std::cos(w0);
    const double sinw0 = std::sin(w0);
    const double alpha = sinw0 / (2.0 * std::max(0.01, static_cast<double>(q)));

    const double b0 = 1.0 + alpha * A;
    const double b1 = -2.0 * cosw0;
    const double b2 = 1.0 - alpha * A;
    const double a0 = 1.0 + alpha / A;
    const double a1 = -2.0 * cosw0;
    const double a2 = 1.0 - alpha / A;

    bq.a0 = static_cast<float>(b0 / a0);
    bq.a1 = static_cast<float>(b1 / a0);
    bq.a2 = static_cast<float>(b2 / a0);
    bq.b1 = static_cast<float>(a1 / a0);
    bq.b2 = static_cast<float>(a2 / a0);
}

float EQModule::Biquad::processL(float x) {
    const float y = a0 * x + zL1;
    zL1 = a1 * x - b1 * y + zL2;
    zL2 = a2 * x - b2 * y;
    return y;
}

float EQModule::Biquad::processR(float x) {
    const float y = a0 * x + zR1;
    zR1 = a1 * x - b1 * y + zR2;
    zR2 = a2 * x - b2 * y;
    return y;
}

void EQModule::Biquad::reset() {
    zL1 = zL2 = zR1 = zR2 = 0.0f;
}

void EQModule::process(const ProcessContext& ctx) {
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
        float l = inL[i];
        float r = inR[i];
        l = low_.processL(l); r = low_.processR(r);
        l = mid_.processL(l); r = mid_.processR(r);
        l = high_.processL(l); r = high_.processR(r);
        outL[i] = l;
        outR[i] = r;
    }
}

}  // namespace chips
