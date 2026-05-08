// WavetableSynth.hpp — synth con wavetable morphing entre 4 formas
// (sine, triangle, saw, square). Polifónico (4 voces). RT-safe.

#ifndef CHIPS_WAVETABLE_SYNTH_HPP
#define CHIPS_WAVETABLE_SYNTH_HPP

#include "AdsrEnvelope.hpp"
#include "IModule.hpp"

#include <array>
#include <cstdint>

namespace chips {

class WavetableSynth : public IModule {
public:
    static constexpr int kNumVoices = 4;
    static constexpr int kTableSize = 1024;
    static constexpr int kNumWaves = 4;  // sine, triangle, saw, square

    enum Param : uint32_t {
        ParamVolume = 0,
        ParamPosition = 1,  // 0..(kNumWaves-1) en flotante; interpola
        ParamAttack = 2,
        ParamDecay = 3,
        ParamSustain = 4,
        ParamRelease = 5,
    };

    WavetableSynth();

    static void forceLink();

    const char* typeId() const override { return "wavetable_synth"; }
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
        AdsrEnvelope envelope{};
        double phase = 0.0;       // 0..1
        double frequency = 0.0;
        int midi = -1;
        float velocity = 0.0f;
    };

    static double midiToFrequency(int midi);
    static void initializeTables(std::array<std::array<float, kTableSize>, kNumWaves>& tables);
    Voice* allocateVoice(int midi);
    float sampleAtPosition(float phase01, float position) const;

    std::array<std::array<float, kTableSize>, kNumWaves> tables_{};
    std::array<Voice, kNumVoices> voices_{};
    int nextVoice_ = 0;

    double sampleRate_ = 48000.0;

    float volume_ = 0.5f;
    float position_ = 0.0f;       // 0=sine, 1=triangle, 2=saw, 3=square
    float attack_ = 0.005f;
    float decay_ = 0.2f;
    float sustain_ = 0.6f;
    float release_ = 0.4f;
};

}  // namespace chips

#endif  // CHIPS_WAVETABLE_SYNTH_HPP
