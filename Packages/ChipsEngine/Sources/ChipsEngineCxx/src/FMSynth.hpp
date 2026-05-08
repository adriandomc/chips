// FMSynth.hpp — 2-op FM synth (carrier + modulator), polifónico (4 voces).
// Implementa IModule, RT-safe en process().

#ifndef CHIPS_FM_SYNTH_HPP
#define CHIPS_FM_SYNTH_HPP

#include "AdsrEnvelope.hpp"
#include "IModule.hpp"

#include <array>
#include <cstdint>

namespace chips {

class FMSynth : public IModule {
public:
    static constexpr int kNumVoices = 4;

    enum Param : uint32_t {
        ParamVolume = 0,
        ParamRatio = 1,
        ParamModIndex = 2,
        ParamAttack = 3,
        ParamDecay = 4,
        ParamSustain = 5,
        ParamRelease = 6,
    };

    FMSynth();

    static void forceLink();

    const char* typeId() const override { return "fm_synth"; }
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
        double carrierPhase = 0.0;
        double modulatorPhase = 0.0;
        double carrierFrequency = 0.0;
        int midi = -1;
        float velocity = 0.0f;
    };

    static double midiToFrequency(int midi);
    Voice* allocateVoice(int midi);

    std::array<Voice, kNumVoices> voices_{};
    int nextVoice_ = 0;

    double sampleRate_ = 48000.0;

    float volume_ = 0.5f;
    float ratio_ = 2.0f;       // mod_freq / carrier_freq
    float modIndex_ = 1.0f;    // 0..10
    float attack_ = 0.005f;
    float decay_ = 0.2f;
    float sustain_ = 0.6f;
    float release_ = 0.4f;
};

}  // namespace chips

#endif  // CHIPS_FM_SYNTH_HPP
