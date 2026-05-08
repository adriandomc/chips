// SubtractiveSynth.hpp — sintetizador sustractivo monofónico (saw + LP filter + ADSR).
// Implementa IModule. RT-safe en process(). Demostración del plug-and-play
// modular: añadir este módulo es solo un .hpp + .cpp + entry en touchAllModules.

#ifndef CHIPS_SUBTRACTIVE_SYNTH_HPP
#define CHIPS_SUBTRACTIVE_SYNTH_HPP

#include "AdsrEnvelope.hpp"
#include "IModule.hpp"

#include <cstdint>

namespace chips {

class SubtractiveSynth : public IModule {
public:
    enum Param : uint32_t {
        ParamVolume = 0,
        ParamCutoff = 1,
        ParamResonance = 2,
        ParamAttack = 3,
        ParamDecay = 4,
        ParamSustain = 5,
        ParamRelease = 6,
    };

    SubtractiveSynth();

    static void forceLink();

    const char* typeId() const override { return "subtractive_synth"; }
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
    /// Filtro biquad low-pass (RBJ cookbook). Recalcula coeficientes en cada
    /// cambio de cutoff/resonance — fuera del loop de samples.
    struct BiquadLP {
        float a0 = 1.0f, a1 = 0.0f, a2 = 0.0f;
        float b1 = 0.0f, b2 = 0.0f;
        float z1 = 0.0f, z2 = 0.0f;

        void recompute(double sampleRate, float cutoffHz, float resonanceQ);
        float process(float input);
        void reset();
    };

    void recomputeFilter();
    static double midiToFrequency(int midi);

    AdsrEnvelope envelope_{};
    BiquadLP filter_{};
    double sampleRate_ = 48000.0;
    double phase_ = 0.0;
    double frequency_ = 0.0;
    int currentMidi_ = -1;

    float volume_ = 0.4f;
    float cutoffHz_ = 2000.0f;
    float resonanceQ_ = 0.707f;
    float attack_ = 0.01f;
    float decay_ = 0.15f;
    float sustain_ = 0.7f;
    float release_ = 0.3f;
};

}  // namespace chips

#endif  // CHIPS_SUBTRACTIVE_SYNTH_HPP
