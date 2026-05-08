// BeatBox.hpp — drum sampler sintético. 8 sonidos sintéticos disparados por
// MIDI notes 36..43. Polifonía: 8 voces (una por drum). RT-safe.

#ifndef CHIPS_BEATBOX_HPP
#define CHIPS_BEATBOX_HPP

#include "IModule.hpp"

#include <array>
#include <cstdint>

namespace chips {

class BeatBox : public IModule {
public:
    static constexpr int kNumDrums = 8;
    static constexpr int kBaseMidi = 36;  // C2

    enum Param : uint32_t {
        ParamVolume = 0,
        ParamDecay = 1,   // multiplicador de los decays internos (0.5..2.0)
        ParamTone = 2,    // cutoff del HP/LP de los drums noise (200..8000 Hz)
    };

    BeatBox();

    static void forceLink();

    const char* typeId() const override { return "beatbox"; }
    void prepare(double sampleRate, int maxFrames) override;
    void reset() override;
    void process(const ProcessContext& ctx) override;
    void handleParameterChange(uint32_t paramId, float value) override;
    void handleNoteOn(int midi, float velocity) override;
    void handleNoteOff(int midi) override;

    int numAudioInputs() const override { return 0; }
    int numAudioOutputs() const override { return 2; }

    int numParameters() const override;
    ParamSpec parameterAt(int index) const override;

private:
    struct Voice {
        bool active = false;
        int drumIndex = 0;
        float velocity = 1.0f;
        double timeSec = 0.0;
        // RNG por voz para noise determinístico.
        uint32_t rngState = 0xCAFEBABEu;
        // Estados de filtro 1-polo (para drums basados en noise).
        float lpZ = 0.0f;
        float hpZ = 0.0f;
    };

    static float voiceSample(Voice& voice, double sampleRate, float decayMul, float toneCutoff);
    static float xorshift01(uint32_t& state);

    std::array<Voice, kNumDrums> voices_{};
    double sampleRate_ = 48000.0;

    float volume_ = 0.7f;
    float decayMul_ = 1.0f;
    float toneCutoff_ = 2000.0f;
};

}  // namespace chips

#endif  // CHIPS_BEATBOX_HPP
