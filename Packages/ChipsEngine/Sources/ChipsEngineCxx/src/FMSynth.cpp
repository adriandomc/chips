// FMSynth.cpp

#include "FMSynth.hpp"

#include "ModuleRegistry.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace chips {

namespace {
constexpr double kTwoPi = 6.28318530717958647692;

const ParamSpec kFMSynthParamSpecs[] = {
    {FMSynth::ParamVolume, "volume", "", 0.0f, 1.0f, 0.5f},
    {FMSynth::ParamRatio, "ratio", "", 0.1f, 10.0f, 2.0f},
    {FMSynth::ParamModIndex, "modIndex", "", 0.0f, 10.0f, 1.0f},
    {FMSynth::ParamAttack, "attack", "s", 0.001f, 4.0f, 0.005f},
    {FMSynth::ParamDecay, "decay", "s", 0.001f, 4.0f, 0.2f},
    {FMSynth::ParamSustain, "sustain", "", 0.0f, 1.0f, 0.6f},
    {FMSynth::ParamRelease, "release", "s", 0.001f, 8.0f, 0.4f},
};

[[gnu::used]] const bool kRegistered =
    ModuleRegistry::instance().register_("fm_synth", [] { return std::unique_ptr<IModule>(new FMSynth()); });
}  // namespace

void FMSynth::forceLink() {}

int FMSynth::numParameters() const {
    return static_cast<int>(sizeof(kFMSynthParamSpecs) / sizeof(kFMSynthParamSpecs[0]));
}

ParamSpec FMSynth::parameterAt(int index) const {
    if (index < 0 || index >= numParameters()) {
        return ParamSpec{};
    }
    return kFMSynthParamSpecs[index];
}

FMSynth::FMSynth() {
    for (auto& voice : voices_) {
        voice.envelope.setAttack(attack_);
        voice.envelope.setDecay(decay_);
        voice.envelope.setSustain(sustain_);
        voice.envelope.setRelease(release_);
    }
}

void FMSynth::prepare(double sampleRate, int /*maxFrames*/) {
    sampleRate_ = sampleRate > 0 ? sampleRate : 48000.0;
    for (auto& voice : voices_) {
        voice.envelope.prepare(sampleRate_);
        voice.envelope.setAttack(attack_);
        voice.envelope.setDecay(decay_);
        voice.envelope.setSustain(sustain_);
        voice.envelope.setRelease(release_);
    }
    reset();
}

void FMSynth::reset() {
    for (auto& voice : voices_) {
        voice.envelope.reset();
        voice.carrierPhase = 0.0;
        voice.modulatorPhase = 0.0;
        voice.midi = -1;
        voice.velocity = 0.0f;
    }
    nextVoice_ = 0;
}

void FMSynth::handleParameterChange(uint32_t paramId, float value) {
    switch (paramId) {
    case ParamVolume:
        volume_ = std::max(0.0f, std::min(1.0f, value));
        break;
    case ParamRatio:
        ratio_ = std::max(0.1f, std::min(10.0f, value));
        break;
    case ParamModIndex:
        modIndex_ = std::max(0.0f, std::min(10.0f, value));
        break;
    case ParamAttack:
        attack_ = value;
        for (auto& voice : voices_) voice.envelope.setAttack(value);
        break;
    case ParamDecay:
        decay_ = value;
        for (auto& voice : voices_) voice.envelope.setDecay(value);
        break;
    case ParamSustain:
        sustain_ = value;
        for (auto& voice : voices_) voice.envelope.setSustain(value);
        break;
    case ParamRelease:
        release_ = value;
        for (auto& voice : voices_) voice.envelope.setRelease(value);
        break;
    }
}

FMSynth::Voice* FMSynth::allocateVoice(int midi) {
    // Reuso si la voz ya tiene esta nota.
    for (auto& voice : voices_) {
        if (voice.midi == midi && voice.envelope.isActive()) {
            return &voice;
        }
    }
    // Voz idle.
    for (auto& voice : voices_) {
        if (!voice.envelope.isActive()) {
            return &voice;
        }
    }
    // Voice stealing: round-robin.
    Voice* victim = &voices_[static_cast<size_t>(nextVoice_)];
    nextVoice_ = (nextVoice_ + 1) % kNumVoices;
    return victim;
}

void FMSynth::handleNoteOn(int midi, float velocity) {
    Voice* voice = allocateVoice(midi);
    voice->midi = midi;
    voice->velocity = velocity;
    voice->carrierFrequency = midiToFrequency(midi);
    voice->carrierPhase = 0.0;
    voice->modulatorPhase = 0.0;
    voice->envelope.noteOn();
}

void FMSynth::handleNoteOff(int midi) {
    for (auto& voice : voices_) {
        if (voice.midi == midi) {
            voice.envelope.noteOff();
        }
    }
}

void FMSynth::process(const ProcessContext& ctx) {
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

    const float voiceScale = 1.0f / static_cast<float>(kNumVoices);
    for (auto& voice : voices_) {
        if (!voice.envelope.isActive() || voice.carrierFrequency <= 0.0) {
            continue;
        }
        const double carrierIncrement = voice.carrierFrequency / sampleRate_;
        const double modulatorIncrement = (voice.carrierFrequency * static_cast<double>(ratio_)) / sampleRate_;
        for (int i = 0; i < ctx.frames; ++i) {
            const float modulator = static_cast<float>(std::sin(kTwoPi * voice.modulatorPhase));
            const double carrierAngle = kTwoPi * voice.carrierPhase
                                        + static_cast<double>(modIndex_) * static_cast<double>(modulator);
            const float carrier = static_cast<float>(std::sin(carrierAngle));
            const float env = voice.envelope.process();
            const float sample = carrier * env * volume_ * voice.velocity * voiceScale;
            outL[i] += sample;
            outR[i] += sample;

            voice.carrierPhase += carrierIncrement;
            if (voice.carrierPhase >= 1.0) voice.carrierPhase -= 1.0;
            voice.modulatorPhase += modulatorIncrement;
            if (voice.modulatorPhase >= 1.0) voice.modulatorPhase -= 1.0;
        }
    }
}

double FMSynth::midiToFrequency(int midi) {
    return 440.0 * std::pow(2.0, (midi - 69) / 12.0);
}

}  // namespace chips
