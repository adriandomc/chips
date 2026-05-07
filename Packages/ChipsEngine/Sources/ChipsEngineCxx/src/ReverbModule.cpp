// ReverbModule.cpp — Schroeder reverb: combs en paralelo + allpass en serie.

#include "ReverbModule.hpp"

#include "ModuleRegistry.hpp"

#include <algorithm>

namespace chips {

namespace {
// Delays clásicos de Schroeder (en samples a 44.1 kHz). Se escalan a la SR real.
constexpr int kCombDelays44k[] = {1557, 1617, 1491, 1422};
constexpr int kAllpassDelays44k[] = {225, 556};

const ParamSpec kReverbParamSpecs[] = {
    {ReverbModule::ParamRoomSize, "room_size", "", 0.0f, 1.0f, 0.7f},
    {ReverbModule::ParamDamping, "damping", "", 0.0f, 1.0f, 0.3f},
    {ReverbModule::ParamWet, "wet", "", 0.0f, 1.0f, 0.2f},
};

[[gnu::used]] const bool kRegistered =
    ModuleRegistry::instance().register_("reverb", [] { return std::unique_ptr<IModule>(new ReverbModule()); });
}  // namespace

void ReverbModule::forceLink() {}

int ReverbModule::numParameters() const {
    return static_cast<int>(sizeof(kReverbParamSpecs) / sizeof(kReverbParamSpecs[0]));
}

ParamSpec ReverbModule::parameterAt(int index) const {
    if (index < 0 || index >= numParameters()) {
        return ParamSpec{};
    }
    return kReverbParamSpecs[index];
}

float ReverbModule::CombFilter::process(float input) {
    if (buffer.empty()) {
        return input;
    }
    const float delayed = buffer[static_cast<size_t>(writeIdx)];
    // One-pole lowpass en el feedback path.
    prev = delayed * (1.0f - damping) + prev * damping;
    buffer[static_cast<size_t>(writeIdx)] = input + prev * feedback;
    writeIdx++;
    if (writeIdx >= static_cast<int>(buffer.size())) {
        writeIdx = 0;
    }
    return delayed;
}

void ReverbModule::CombFilter::reset() {
    std::fill(buffer.begin(), buffer.end(), 0.0f);
    writeIdx = 0;
    prev = 0.0f;
}

float ReverbModule::AllpassFilter::process(float input) {
    if (buffer.empty()) {
        return input;
    }
    const float delayed = buffer[static_cast<size_t>(writeIdx)];
    const float output = -input + delayed;
    buffer[static_cast<size_t>(writeIdx)] = input + delayed * feedback;
    writeIdx++;
    if (writeIdx >= static_cast<int>(buffer.size())) {
        writeIdx = 0;
    }
    return output;
}

void ReverbModule::AllpassFilter::reset() {
    std::fill(buffer.begin(), buffer.end(), 0.0f);
    writeIdx = 0;
}

void ReverbModule::prepare(double sampleRate, int /*maxFrames*/) {
    sampleRate_ = sampleRate > 0 ? sampleRate : 48000.0;
    const float scale = static_cast<float>(sampleRate_ / 44100.0);
    for (int i = 0; i < kNumCombs; ++i) {
        const int delay = std::max(1, static_cast<int>(static_cast<float>(kCombDelays44k[i]) * scale));
        combs_[static_cast<size_t>(i)].buffer.assign(static_cast<size_t>(delay), 0.0f);
        combs_[static_cast<size_t>(i)].writeIdx = 0;
    }
    for (int i = 0; i < kNumAllpass; ++i) {
        const int delay = std::max(1, static_cast<int>(static_cast<float>(kAllpassDelays44k[i]) * scale));
        allpass_[static_cast<size_t>(i)].buffer.assign(static_cast<size_t>(delay), 0.0f);
        allpass_[static_cast<size_t>(i)].writeIdx = 0;
    }
    updateInternalParams();
}

void ReverbModule::reset() {
    for (auto& comb : combs_) {
        comb.reset();
    }
    for (auto& filter : allpass_) {
        filter.reset();
    }
}

void ReverbModule::updateInternalParams() {
    // roomSize 0..1 → comb feedback 0.6..0.96
    const float fb = 0.6f + roomSize_ * 0.36f;
    for (auto& comb : combs_) {
        comb.feedback = fb;
        comb.damping = damping_;
    }
}

void ReverbModule::handleParameterChange(uint32_t paramId, float value) {
    switch (paramId) {
    case ParamRoomSize:
        roomSize_ = std::max(0.0f, std::min(1.0f, value));
        updateInternalParams();
        break;
    case ParamDamping:
        damping_ = std::max(0.0f, std::min(1.0f, value));
        updateInternalParams();
        break;
    case ParamWet:
        wet_ = std::max(0.0f, std::min(1.0f, value));
        break;
    default:
        break;
    }
}

void ReverbModule::process(const ProcessContext& ctx) {
    if (ctx.numAudioIn < 2 || ctx.numAudioOut < 2 || ctx.frames <= 0) {
        return;
    }
    const float* inL = ctx.audioIn[0];
    const float* inR = ctx.audioIn[1];
    float* outL = ctx.audioOut[0];
    float* outR = ctx.audioOut[1];
    if (inL == nullptr || inR == nullptr || outL == nullptr || outR == nullptr) {
        return;
    }

    for (int i = 0; i < ctx.frames; ++i) {
        const float monoIn = (inL[i] + inR[i]) * 0.5f;
        float wetSum = 0.0f;
        for (auto& comb : combs_) {
            wetSum += comb.process(monoIn);
        }
        for (auto& filter : allpass_) {
            wetSum = filter.process(wetSum);
        }
        // Stereo spread sutil: L con la wet, R con un mix ligeramente distinto.
        const float wetL = wetSum * 0.4f;
        const float wetR = wetSum * 0.4f;
        outL[i] = inL[i] * (1.0f - wet_) + wetL * wet_;
        outR[i] = inR[i] * (1.0f - wet_) + wetR * wet_;
    }
}

}  // namespace chips
