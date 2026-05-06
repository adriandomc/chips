// AdditiveSynth.hpp — sintetizador aditivo polifónico (8 voces × 16 partials).
// Implementa IModule. RT-safe en process().

#ifndef CHIPS_ADDITIVE_SYNTH_HPP
#define CHIPS_ADDITIVE_SYNTH_HPP

#include "AdsrEnvelope.hpp"
#include "IModule.hpp"

#include <array>
#include <cstdint>

namespace chips {

class AdditiveSynth : public IModule {
public:
    static constexpr int kMaxVoices = 8;
    static constexpr int kMaxPartials = 16;

    enum Param : uint32_t {
        ParamVolume = 0,
        ParamAttack = 1,
        ParamDecay = 2,
        ParamSustain = 3,
        ParamRelease = 4,
        ParamTilt = 5,  // 0 = solo fundamental, 1 = serie tipo saw (1, 1/2, 1/3, ...)
    };

    AdditiveSynth();

    void prepare(double sampleRate, int maxFrames) override;
    void reset() override;
    void process(const ProcessContext& ctx) override;
    void handleParameterChange(uint32_t paramId, float value) override;
    void handleNoteOn(int midi, float velocity) override;
    void handleNoteOff(int midi) override;

    int numAudioInputs() const override { return 0; }
    int numAudioOutputs() const override { return 2; }

private:
    struct Voice {
        AdsrEnvelope envelope;
        int midiNote = -1;
        float velocity = 0.0f;
        double frequency = 0.0;
        std::array<double, kMaxPartials> phases{};
    };

    void recomputePartialAmplitudes();
    void updateAllEnvelopes();
    int findVoice(int midi);
    int findFreeVoice();
    static double midiToFrequency(int midi);

    std::array<Voice, kMaxVoices> voices_{};
    std::array<float, kMaxPartials> partialAmps_{};

    double sampleRate_ = 48000.0;
    float volume_ = 0.5f;
    float attack_ = 0.01f;
    float decay_ = 0.1f;
    float sustain_ = 0.7f;
    float release_ = 0.3f;
    float tilt_ = 0.5f;
};

}  // namespace chips

#endif  // CHIPS_ADDITIVE_SYNTH_HPP
