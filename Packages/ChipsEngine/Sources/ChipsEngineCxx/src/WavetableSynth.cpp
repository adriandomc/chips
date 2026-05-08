// WavetableSynth.cpp

#include "WavetableSynth.hpp"

#include "ModuleRegistry.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace chips {

namespace {
constexpr double kTwoPi = 6.28318530717958647692;

const ParamSpec kWavetableSynthParamSpecs[] = {
    {WavetableSynth::ParamVolume, "volume", "", 0.0f, 1.0f, 0.5f},
    {WavetableSynth::ParamPosition, "position", "",
     0.0f, static_cast<float>(WavetableSynth::kNumWaves - 1), 0.0f},
    {WavetableSynth::ParamAttack, "attack", "s", 0.001f, 4.0f, 0.005f},
    {WavetableSynth::ParamDecay, "decay", "s", 0.001f, 4.0f, 0.2f},
    {WavetableSynth::ParamSustain, "sustain", "", 0.0f, 1.0f, 0.6f},
    {WavetableSynth::ParamRelease, "release", "s", 0.001f, 8.0f, 0.4f},
};

[[gnu::used]] const bool kRegistered = ModuleRegistry::instance().register_(
    "wavetable_synth", [] { return std::unique_ptr<IModule>(new WavetableSynth()); });
}  // namespace

void WavetableSynth::forceLink() {}

int WavetableSynth::numParameters() const {
    return static_cast<int>(sizeof(kWavetableSynthParamSpecs) / sizeof(kWavetableSynthParamSpecs[0]));
}

ParamSpec WavetableSynth::parameterAt(int index) const {
    if (index < 0 || index >= numParameters()) {
        return ParamSpec{};
    }
    return kWavetableSynthParamSpecs[index];
}

WavetableSynth::WavetableSynth() {
    initializeTables(tables_);
    for (auto& voice : voices_) {
        voice.envelope.setAttack(attack_);
        voice.envelope.setDecay(decay_);
        voice.envelope.setSustain(sustain_);
        voice.envelope.setRelease(release_);
    }
}

void WavetableSynth::initializeTables(std::array<std::array<float, kTableSize>, kNumWaves>& tables) {
    for (int i = 0; i < kTableSize; ++i) {
        const double phase01 = static_cast<double>(i) / kTableSize;
        const double angle = kTwoPi * phase01;
        // 0: sine
        tables[0][static_cast<size_t>(i)] = static_cast<float>(std::sin(angle));
        // 1: triangle
        tables[1][static_cast<size_t>(i)] = static_cast<float>(
            (phase01 < 0.5) ? (4.0 * phase01 - 1.0) : (3.0 - 4.0 * phase01));
        // 2: saw (bipolar)
        tables[2][static_cast<size_t>(i)] = static_cast<float>(2.0 * phase01 - 1.0);
        // 3: square
        tables[3][static_cast<size_t>(i)] = phase01 < 0.5 ? 1.0f : -1.0f;
    }
}

void WavetableSynth::prepare(double sampleRate, int /*maxFrames*/) {
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

void WavetableSynth::reset() {
    for (auto& voice : voices_) {
        voice.envelope.reset();
        voice.phase = 0.0;
        voice.midi = -1;
        voice.velocity = 0.0f;
    }
    nextVoice_ = 0;
}

void WavetableSynth::handleParameterChange(uint32_t paramId, float value) {
    switch (paramId) {
    case ParamVolume:
        volume_ = std::max(0.0f, std::min(1.0f, value));
        break;
    case ParamPosition:
        position_ = std::max(0.0f, std::min(static_cast<float>(kNumWaves - 1), value));
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

WavetableSynth::Voice* WavetableSynth::allocateVoice(int midi) {
    for (auto& voice : voices_) {
        if (voice.midi == midi && voice.envelope.isActive()) {
            return &voice;
        }
    }
    for (auto& voice : voices_) {
        if (!voice.envelope.isActive()) {
            return &voice;
        }
    }
    Voice* victim = &voices_[static_cast<size_t>(nextVoice_)];
    nextVoice_ = (nextVoice_ + 1) % kNumVoices;
    return victim;
}

void WavetableSynth::handleNoteOn(int midi, float velocity) {
    Voice* voice = allocateVoice(midi);
    voice->midi = midi;
    voice->velocity = velocity;
    voice->frequency = midiToFrequency(midi);
    voice->phase = 0.0;
    voice->envelope.noteOn();
}

void WavetableSynth::handleNoteOff(int midi) {
    for (auto& voice : voices_) {
        if (voice.midi == midi) {
            voice.envelope.noteOff();
        }
    }
}

float WavetableSynth::sampleAtPosition(float phase01, float position) const {
    const int waveIndexLow = static_cast<int>(std::floor(position));
    const int waveIndexHigh = std::min(kNumWaves - 1, waveIndexLow + 1);
    const float waveBlend = position - static_cast<float>(waveIndexLow);

    const float pos = phase01 * static_cast<float>(kTableSize);
    const int sampleIndex = static_cast<int>(std::floor(pos)) % kTableSize;
    const int sampleNext = (sampleIndex + 1) % kTableSize;
    const float sampleBlend = pos - std::floor(pos);

    const auto interpolate = [&](int waveIdx) {
        const auto& table = tables_[static_cast<size_t>(waveIdx)];
        const float a = table[static_cast<size_t>(sampleIndex)];
        const float b = table[static_cast<size_t>(sampleNext)];
        return a + (b - a) * sampleBlend;
    };
    const float lowSample = interpolate(waveIndexLow);
    const float highSample = interpolate(waveIndexHigh);
    return lowSample + (highSample - lowSample) * waveBlend;
}

void WavetableSynth::process(const ProcessContext& ctx) {
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
        if (!voice.envelope.isActive() || voice.frequency <= 0.0) {
            continue;
        }
        const double increment = voice.frequency / sampleRate_;
        for (int i = 0; i < ctx.frames; ++i) {
            const float wave = sampleAtPosition(static_cast<float>(voice.phase), position_);
            const float env = voice.envelope.process();
            const float sample = wave * env * volume_ * voice.velocity * voiceScale;
            outL[i] += sample;
            outR[i] += sample;
            voice.phase += increment;
            if (voice.phase >= 1.0) voice.phase -= 1.0;
        }
    }
}

double WavetableSynth::midiToFrequency(int midi) {
    return 440.0 * std::pow(2.0, (midi - 69) / 12.0);
}

}  // namespace chips
