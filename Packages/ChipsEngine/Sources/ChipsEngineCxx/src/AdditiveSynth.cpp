// AdditiveSynth.cpp

#include "AdditiveSynth.hpp"

#include "ModuleRegistry.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace chips {

namespace {
constexpr double kTwoPi = 6.28318530717958647692;

const ParamSpec kAdditiveSynthParamSpecs[] = {
    {AdditiveSynth::ParamVolume, "volume", "", 0.0f, 1.0f, 0.5f},
    {AdditiveSynth::ParamAttack, "attack", "s", 0.001f, 4.0f, 0.01f},
    {AdditiveSynth::ParamDecay, "decay", "s", 0.001f, 4.0f, 0.15f},
    {AdditiveSynth::ParamSustain, "sustain", "", 0.0f, 1.0f, 0.7f},
    {AdditiveSynth::ParamRelease, "release", "s", 0.001f, 8.0f, 0.4f},
    {AdditiveSynth::ParamTilt, "tilt", "", 0.0f, 1.0f, 0.5f},
};

[[gnu::used]] const bool kRegistered = ModuleRegistry::instance().register_(
    "additive_synth", [] { return std::unique_ptr<IModule>(new AdditiveSynth()); });
}  // namespace

void AdditiveSynth::forceLink() {}

int AdditiveSynth::numParameters() const {
    return static_cast<int>(sizeof(kAdditiveSynthParamSpecs) / sizeof(kAdditiveSynthParamSpecs[0]));
}

ParamSpec AdditiveSynth::parameterAt(int index) const {
    if (index < 0 || index >= numParameters()) {
        return ParamSpec{};
    }
    return kAdditiveSynthParamSpecs[index];
}

AdditiveSynth::AdditiveSynth() {
    recomputePartialAmplitudes();
}

void AdditiveSynth::prepare(double sampleRate, int /*maxFrames*/) {
    sampleRate_ = sampleRate > 0 ? sampleRate : 48000.0;
    for (auto& v : voices_) {
        v.envelope.prepare(sampleRate_);
        v.envelope.reset();
        v.midiNote = -1;
        v.velocity = 0.0f;
        v.frequency = 0.0;
        v.phases.fill(0.0);
    }
    updateAllEnvelopes();
}

void AdditiveSynth::reset() {
    for (auto& v : voices_) {
        v.envelope.reset();
        v.midiNote = -1;
        v.velocity = 0.0f;
        v.phases.fill(0.0);
    }
}

void AdditiveSynth::handleParameterChange(uint32_t paramId, float value) {
    switch (paramId) {
    case ParamVolume:
        volume_ = std::max(0.0f, std::min(1.0f, value));
        break;
    case ParamAttack:
        attack_ = std::max(0.001f, value);
        updateAllEnvelopes();
        break;
    case ParamDecay:
        decay_ = std::max(0.001f, value);
        updateAllEnvelopes();
        break;
    case ParamSustain:
        sustain_ = std::max(0.0f, std::min(1.0f, value));
        updateAllEnvelopes();
        break;
    case ParamRelease:
        release_ = std::max(0.001f, value);
        updateAllEnvelopes();
        break;
    case ParamTilt:
        tilt_ = std::max(0.0f, std::min(1.0f, value));
        recomputePartialAmplitudes();
        break;
    default:
        break;
    }
}

void AdditiveSynth::updateAllEnvelopes() {
    for (auto& v : voices_) {
        v.envelope.setAttack(attack_);
        v.envelope.setDecay(decay_);
        v.envelope.setSustain(sustain_);
        v.envelope.setRelease(release_);
    }
}

void AdditiveSynth::recomputePartialAmplitudes() {
    // Mezcla entre fundamental pura y serie 1/n (saw). Tilt 0 = solo fundamental,
    // 1 = serie completa. El total se normaliza para evitar clipping.
    float total = 0.0f;
    for (int i = 0; i < kMaxPartials; ++i) {
        const float harmonic = 1.0f / static_cast<float>(i + 1);
        const float fundamental = i == 0 ? 1.0f : 0.0f;
        partialAmps_[static_cast<size_t>(i)] = (1.0f - tilt_) * fundamental + tilt_ * harmonic;
        total += partialAmps_[static_cast<size_t>(i)];
    }
    if (total > 0.0f) {
        for (auto& a : partialAmps_) {
            a /= total;
        }
    }
}

int AdditiveSynth::findVoice(int midi) {
    for (size_t i = 0; i < voices_.size(); ++i) {
        if (voices_[i].midiNote == midi) {
            return static_cast<int>(i);
        }
    }
    return -1;
}

int AdditiveSynth::findFreeVoice() {
    for (size_t i = 0; i < voices_.size(); ++i) {
        if (!voices_[i].envelope.isActive()) {
            return static_cast<int>(i);
        }
    }
    // Voice stealing: el más viejo (índice 0). Sin tracking de age, simple round-robin.
    return 0;
}

double AdditiveSynth::midiToFrequency(int midi) {
    return 440.0 * std::pow(2.0, (midi - 69) / 12.0);
}

void AdditiveSynth::handleNoteOn(int midi, float velocity) {
    if (midi < 0 || midi > 127) {
        return;
    }
    int idx = findVoice(midi);
    if (idx < 0) {
        idx = findFreeVoice();
    }
    Voice& v = voices_[static_cast<size_t>(idx)];
    v.midiNote = midi;
    v.velocity = std::max(0.0f, std::min(1.0f, velocity));
    v.frequency = midiToFrequency(midi);
    v.phases.fill(0.0);
    v.envelope.reset();
    v.envelope.noteOn();
}

void AdditiveSynth::handleNoteOff(int midi) {
    int idx = findVoice(midi);
    if (idx < 0) {
        return;
    }
    Voice& v = voices_[static_cast<size_t>(idx)];
    v.envelope.noteOff();
    v.midiNote = -1;
}

void AdditiveSynth::process(const ProcessContext& ctx) {
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

    const double sr = sampleRate_;
    for (auto& voice : voices_) {
        if (!voice.envelope.isActive()) {
            continue;
        }
        const double freq = voice.frequency;
        for (int frame = 0; frame < ctx.frames; ++frame) {
            float sample = 0.0f;
            for (int p = 0; p < kMaxPartials; ++p) {
                const double partialFreq = freq * static_cast<double>(p + 1);
                if (partialFreq * 2.0 >= sr) {
                    break;  // Nyquist; ignoramos parciales por encima.
                }
                const double phaseInc = (kTwoPi * partialFreq) / sr;
                voice.phases[static_cast<size_t>(p)] += phaseInc;
                if (voice.phases[static_cast<size_t>(p)] >= kTwoPi) {
                    voice.phases[static_cast<size_t>(p)] -= kTwoPi;
                }
                sample += partialAmps_[static_cast<size_t>(p)] *
                          static_cast<float>(std::sin(voice.phases[static_cast<size_t>(p)]));
            }
            const float env = voice.envelope.process();
            const float out = sample * env * voice.velocity * volume_;
            outL[frame] += out;
            outR[frame] += out;
        }
    }
}

}  // namespace chips
