// DistortionModule.cpp

#include "DistortionModule.hpp"

#include "ModuleRegistry.hpp"

#include <algorithm>
#include <cmath>

namespace chips {

namespace {
const ParamSpec kDistortionParamSpecs[] = {
    {DistortionModule::ParamDrive, "drive", "", 1.0f, 50.0f, 4.0f},
    {DistortionModule::ParamMix, "mix", "", 0.0f, 1.0f, 1.0f},
    {DistortionModule::ParamLevel, "level", "", 0.0f, 1.0f, 0.7f},
};

[[gnu::used]] const bool kRegistered = ModuleRegistry::instance().register_(
    "distortion", [] { return std::unique_ptr<IModule>(new DistortionModule()); });
}  // namespace

void DistortionModule::forceLink() {}

int DistortionModule::numParameters() const {
    return static_cast<int>(sizeof(kDistortionParamSpecs) / sizeof(kDistortionParamSpecs[0]));
}

ParamSpec DistortionModule::parameterAt(int index) const {
    if (index < 0 || index >= numParameters()) {
        return ParamSpec{};
    }
    return kDistortionParamSpecs[index];
}

DistortionModule::DistortionModule() = default;

void DistortionModule::prepare(double /*sampleRate*/, int /*maxFrames*/) {
    reset();
}

void DistortionModule::reset() {}

void DistortionModule::handleParameterChange(uint32_t paramId, float value) {
    switch (paramId) {
    case ParamDrive: drive_ = std::max(1.0f, std::min(50.0f, value)); break;
    case ParamMix: mix_ = std::max(0.0f, std::min(1.0f, value)); break;
    case ParamLevel: level_ = std::max(0.0f, std::min(1.0f, value)); break;
    }
}

void DistortionModule::process(const ProcessContext& ctx) {
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
        const float l = inL[i];
        const float r = inR[i];
        // Soft-clip via tanh, balanceado con tanh(drive) para que mix=1, drive=1 → ~ unity en lineal range.
        const float wetL = std::tanh(l * drive_) / std::tanh(drive_);
        const float wetR = std::tanh(r * drive_) / std::tanh(drive_);
        outL[i] = (l * (1.0f - mix_) + wetL * mix_) * level_;
        outR[i] = (r * (1.0f - mix_) + wetR * mix_) * level_;
    }
}

}  // namespace chips
