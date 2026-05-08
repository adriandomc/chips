// SubtractiveSynth.cpp

#include "SubtractiveSynth.hpp"

#include "ModuleRegistry.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace chips {

namespace {
constexpr double kTwoPi = 6.28318530717958647692;

const ParamSpec kSubtractiveSynthParamSpecs[] = {
    {SubtractiveSynth::ParamVolume, "volume", "", 0.0f, 1.0f, 0.4f},
    {SubtractiveSynth::ParamCutoff, "cutoff", "Hz", 80.0f, 12000.0f, 2000.0f},
    {SubtractiveSynth::ParamResonance, "resonance", "", 0.5f, 8.0f, 0.707f},
    {SubtractiveSynth::ParamAttack, "attack", "s", 0.001f, 4.0f, 0.01f},
    {SubtractiveSynth::ParamDecay, "decay", "s", 0.001f, 4.0f, 0.15f},
    {SubtractiveSynth::ParamSustain, "sustain", "", 0.0f, 1.0f, 0.7f},
    {SubtractiveSynth::ParamRelease, "release", "s", 0.001f, 8.0f, 0.3f},
};

[[gnu::used]] const bool kRegistered = ModuleRegistry::instance().register_(
    "subtractive_synth", [] { return std::unique_ptr<IModule>(new SubtractiveSynth()); });
}  // namespace

void SubtractiveSynth::forceLink() {}

int SubtractiveSynth::numParameters() const {
    return static_cast<int>(sizeof(kSubtractiveSynthParamSpecs) / sizeof(kSubtractiveSynthParamSpecs[0]));
}

ParamSpec SubtractiveSynth::parameterAt(int index) const {
    if (index < 0 || index >= numParameters()) {
        return ParamSpec{};
    }
    return kSubtractiveSynthParamSpecs[index];
}

SubtractiveSynth::SubtractiveSynth() {
    envelope_.setAttack(attack_);
    envelope_.setDecay(decay_);
    envelope_.setSustain(sustain_);
    envelope_.setRelease(release_);
}

void SubtractiveSynth::prepare(double sampleRate, int /*maxFrames*/) {
    sampleRate_ = sampleRate > 0 ? sampleRate : 48000.0;
    envelope_.prepare(sampleRate_);
    envelope_.setAttack(attack_);
    envelope_.setDecay(decay_);
    envelope_.setSustain(sustain_);
    envelope_.setRelease(release_);
    recomputeFilter();
    reset();
}

void SubtractiveSynth::reset() {
    envelope_.reset();
    filter_.reset();
    phase_ = 0.0;
    frequency_ = 0.0;
    currentMidi_ = -1;
}

void SubtractiveSynth::handleParameterChange(uint32_t paramId, float value) {
    switch (paramId) {
    case ParamVolume:
        volume_ = std::max(0.0f, std::min(1.0f, value));
        break;
    case ParamCutoff:
        cutoffHz_ = std::max(20.0f, std::min(20000.0f, value));
        recomputeFilter();
        break;
    case ParamResonance:
        resonanceQ_ = std::max(0.5f, std::min(20.0f, value));
        recomputeFilter();
        break;
    case ParamAttack:
        attack_ = value;
        envelope_.setAttack(value);
        break;
    case ParamDecay:
        decay_ = value;
        envelope_.setDecay(value);
        break;
    case ParamSustain:
        sustain_ = value;
        envelope_.setSustain(value);
        break;
    case ParamRelease:
        release_ = value;
        envelope_.setRelease(value);
        break;
    }
}

void SubtractiveSynth::handleNoteOn(int midi, float /*velocity*/) {
    currentMidi_ = midi;
    frequency_ = midiToFrequency(midi);
    phase_ = 0.0;
    envelope_.noteOn();
}

void SubtractiveSynth::handleNoteOff(int midi) {
    if (midi == currentMidi_) {
        envelope_.noteOff();
    }
}

void SubtractiveSynth::process(const ProcessContext& ctx) {
    if (ctx.numAudioOut < 2 || ctx.audioOut == nullptr || ctx.frames <= 0) {
        return;
    }
    float* outL = ctx.audioOut[0];
    float* outR = ctx.audioOut[1];
    if (outL == nullptr || outR == nullptr) {
        return;
    }
    if (!envelope_.isActive() || frequency_ <= 0.0) {
        std::memset(outL, 0, static_cast<size_t>(ctx.frames) * sizeof(float));
        std::memset(outR, 0, static_cast<size_t>(ctx.frames) * sizeof(float));
        return;
    }
    const double increment = frequency_ / sampleRate_;
    for (int i = 0; i < ctx.frames; ++i) {
        // Saw bipolar [-1, 1] generado a partir de phase [0, 1).
        const float saw = static_cast<float>(2.0 * phase_ - 1.0);
        phase_ += increment;
        if (phase_ >= 1.0) {
            phase_ -= 1.0;
        }
        const float filtered = filter_.process(saw);
        const float env = envelope_.process();
        const float sample = filtered * env * volume_;
        outL[i] = sample;
        outR[i] = sample;
    }
}

void SubtractiveSynth::recomputeFilter() {
    filter_.recompute(sampleRate_, cutoffHz_, resonanceQ_);
}

double SubtractiveSynth::midiToFrequency(int midi) {
    return 440.0 * std::pow(2.0, (midi - 69) / 12.0);
}

void SubtractiveSynth::BiquadLP::recompute(double sampleRate, float cutoffHz, float resonanceQ) {
    // RBJ cookbook low-pass biquad.
    const double w0 = kTwoPi * static_cast<double>(cutoffHz) / std::max(1.0, sampleRate);
    const double cosw0 = std::cos(w0);
    const double sinw0 = std::sin(w0);
    const double q = std::max(0.0001, static_cast<double>(resonanceQ));
    const double alpha = sinw0 / (2.0 * q);
    const double normB0 = (1.0 - cosw0) / 2.0;
    const double normB1 = 1.0 - cosw0;
    const double normB2 = (1.0 - cosw0) / 2.0;
    const double normA0 = 1.0 + alpha;
    const double normA1 = -2.0 * cosw0;
    const double normA2 = 1.0 - alpha;
    a0 = static_cast<float>(normB0 / normA0);
    a1 = static_cast<float>(normB1 / normA0);
    a2 = static_cast<float>(normB2 / normA0);
    b1 = static_cast<float>(normA1 / normA0);
    b2 = static_cast<float>(normA2 / normA0);
}

float SubtractiveSynth::BiquadLP::process(float input) {
    // Direct Form II Transposed.
    const float output = a0 * input + z1;
    z1 = a1 * input - b1 * output + z2;
    z2 = a2 * input - b2 * output;
    return output;
}

void SubtractiveSynth::BiquadLP::reset() {
    z1 = 0.0f;
    z2 = 0.0f;
}

}  // namespace chips
