// BeatBox.cpp

#include "BeatBox.hpp"

#include "ModuleRegistry.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace chips {

namespace {
constexpr double kTwoPi = 6.28318530717958647692;

const ParamSpec kBeatBoxParamSpecs[] = {
    {BeatBox::ParamVolume, "volume", "", 0.0f, 1.0f, 0.7f},
    {BeatBox::ParamDecay, "decay", "", 0.25f, 4.0f, 1.0f},
    {BeatBox::ParamTone, "tone", "Hz", 200.0f, 8000.0f, 2000.0f},
};

[[gnu::used]] const bool kRegistered =
    ModuleRegistry::instance().register_("beatbox", [] { return std::unique_ptr<IModule>(new BeatBox()); });
}  // namespace

void BeatBox::forceLink() {}

int BeatBox::numParameters() const {
    return static_cast<int>(sizeof(kBeatBoxParamSpecs) / sizeof(kBeatBoxParamSpecs[0]));
}

ParamSpec BeatBox::parameterAt(int index) const {
    if (index < 0 || index >= numParameters()) {
        return ParamSpec{};
    }
    return kBeatBoxParamSpecs[index];
}

BeatBox::BeatBox() = default;

void BeatBox::prepare(double sampleRate, int /*maxFrames*/) {
    sampleRate_ = sampleRate > 0 ? sampleRate : 48000.0;
    reset();
}

void BeatBox::reset() {
    for (auto& voice : voices_) {
        voice.active = false;
        voice.timeSec = 0.0;
        voice.lpZ = 0.0f;
        voice.hpZ = 0.0f;
    }
    // Seeds distintas por voz para que el noise de cada drum sea independiente.
    uint32_t seed = 0xCAFEBABEu;
    for (auto& voice : voices_) {
        voice.rngState = seed;
        seed = seed * 1664525u + 1013904223u;
    }
}

void BeatBox::handleParameterChange(uint32_t paramId, float value) {
    switch (paramId) {
    case ParamVolume:
        volume_ = std::max(0.0f, std::min(1.0f, value));
        break;
    case ParamDecay:
        decayMul_ = std::max(0.25f, std::min(4.0f, value));
        break;
    case ParamTone:
        toneCutoff_ = std::max(200.0f, std::min(8000.0f, value));
        break;
    }
}

void BeatBox::handleNoteOn(int midi, float velocity) {
    const int drumIndex = midi - kBaseMidi;
    if (drumIndex < 0 || drumIndex >= kNumDrums) {
        return;
    }
    Voice& voice = voices_[static_cast<size_t>(drumIndex)];
    voice.active = true;
    voice.drumIndex = drumIndex;
    voice.velocity = velocity;
    voice.timeSec = 0.0;
    voice.lpZ = 0.0f;
    voice.hpZ = 0.0f;
}

void BeatBox::handleNoteOff(int /*midi*/) {
    // Drums son one-shot: el note off no apaga la voz; la voz se desactiva
    // cuando su envelope intrínseco alcanza el final.
}

float BeatBox::xorshift01(uint32_t& state) {
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;
    // [-1, 1)
    return static_cast<float>(state) / 2147483648.0f - 1.0f;
}

float BeatBox::voiceSample(Voice& voice, double sampleRate, float decayMul, float toneCutoff) {
    const double t = voice.timeSec;
    const double dt = 1.0 / sampleRate;
    voice.timeSec += dt;
    const float velocity = voice.velocity;

    // Helper: amp envelope exponencial con tau (segundos), modulado por decayMul.
    const auto ampEnv = [decayMul, t](double tau) {
        return static_cast<float>(std::exp(-t / (tau * static_cast<double>(decayMul))));
    };

    // Helper: pitch envelope decay desde startHz a endHz con tau.
    const auto pitchEnv = [decayMul, t](double startHz, double endHz, double tau) {
        const double k = std::exp(-t / (tau * static_cast<double>(decayMul)));
        return endHz + (startHz - endHz) * k;
    };

    // Helper: HP de un polo aplicado a `input` con coeff alpha derivado de cutoff.
    const auto hp = [&voice, sampleRate](float input, float cutoff) {
        const float dtCoeff = static_cast<float>(1.0 / sampleRate);
        const float rc = 1.0f / (kTwoPi * cutoff);
        const float alpha = rc / (rc + dtCoeff);
        const float prev = voice.hpZ;
        voice.hpZ = alpha * (prev + input - voice.lpZ);  // truco: usamos lpZ como prevInput
        voice.lpZ = input;
        return voice.hpZ;
    };

    float sample = 0.0f;
    switch (voice.drumIndex) {
    case 0: {  // Kick: sine pitch decay 80→40Hz, amp decay 0.25s.
        const double freq = pitchEnv(80.0, 40.0, 0.05);
        sample = static_cast<float>(std::sin(kTwoPi * freq * t)) * ampEnv(0.25);
        break;
    }
    case 1: {  // Rim: noise HP, amp decay 0.04s.
        const float n = xorshift01(voice.rngState);
        sample = hp(n, std::max(2000.0f, toneCutoff)) * ampEnv(0.04);
        break;
    }
    case 2: {  // Snare: noise + sine 200Hz, amp decay 0.12s.
        const float n = xorshift01(voice.rngState) * 0.7f;
        const float tone = static_cast<float>(std::sin(kTwoPi * 200.0 * t)) * 0.5f;
        const float mixed = hp(n, std::max(800.0f, toneCutoff * 0.4f)) + tone;
        sample = mixed * ampEnv(0.12);
        break;
    }
    case 3: {  // Clap: 3 noise bursts en 10/20/30ms.
        const float n = xorshift01(voice.rngState);
        float gate = 0.0f;
        const double ms = t * 1000.0;
        if (ms < 5.0) gate = 1.0f;
        else if (ms < 15.0 && ms > 10.0) gate = 1.0f;
        else if (ms < 25.0 && ms > 20.0) gate = 1.0f;
        const float decayed = hp(n, std::max(1500.0f, toneCutoff * 0.8f));
        sample = decayed * gate * ampEnv(0.15);
        break;
    }
    case 4: {  // Tom Low: sine 110→80Hz pitch decay.
        const double freq = pitchEnv(110.0, 80.0, 0.1);
        sample = static_cast<float>(std::sin(kTwoPi * freq * t)) * ampEnv(0.3);
        break;
    }
    case 5: {  // Tom Mid: sine 165→120Hz.
        const double freq = pitchEnv(165.0, 120.0, 0.1);
        sample = static_cast<float>(std::sin(kTwoPi * freq * t)) * ampEnv(0.25);
        break;
    }
    case 6: {  // Tom High: sine 220→160Hz.
        const double freq = pitchEnv(220.0, 160.0, 0.1);
        sample = static_cast<float>(std::sin(kTwoPi * freq * t)) * ampEnv(0.22);
        break;
    }
    case 7: {  // HiHat: noise HP, amp decay 0.06s.
        const float n = xorshift01(voice.rngState);
        sample = hp(n, std::max(4000.0f, toneCutoff)) * ampEnv(0.06);
        break;
    }
    default:
        break;
    }

    // Cortar la voz cuando el env esté esencialmente en silencio.
    if (t > 1.5 || (t > 0.05 && std::fabs(sample) < 1e-5f)) {
        voice.active = false;
    }
    return sample * velocity;
}

void BeatBox::process(const ProcessContext& ctx) {
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

    for (auto& voice : voices_) {
        if (!voice.active) {
            continue;
        }
        for (int i = 0; i < ctx.frames; ++i) {
            const float sample = voiceSample(voice, sampleRate_, decayMul_, toneCutoff_) * volume_;
            outL[i] += sample;
            outR[i] += sample;
            if (!voice.active) break;
        }
    }
}

}  // namespace chips
