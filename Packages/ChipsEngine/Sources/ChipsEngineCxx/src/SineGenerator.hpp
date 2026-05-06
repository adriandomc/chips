// SineGenerator.hpp — generador stereo sinusoide. Implementa IModule.

#ifndef CHIPS_SINE_GENERATOR_HPP
#define CHIPS_SINE_GENERATOR_HPP

#include "IModule.hpp"

#include <atomic>
#include <cstdint>

namespace chips {

class SineGenerator : public IModule {
public:
    enum Param : uint32_t {
        ParamFrequency = 0,
        ParamEnabled = 1,
        ParamAmplitude = 2,
    };

    SineGenerator() = default;

    void prepare(double sampleRate, int maxFrames) override;
    void reset() override;
    void process(const ProcessContext& ctx) override;
    void handleParameterChange(uint32_t paramId, float value) override;

    int numAudioInputs() const override { return 0; }
    int numAudioOutputs() const override { return 2; }

    // Accesores fuera del grafo (control thread; no RT).
    void setFrequency(float hz);
    void setEnabled(bool enabled);
    bool isEnabled() const;
    float frequency() const;

private:
    double sampleRate_ = 48000.0;
    double phase_ = 0.0;
    std::atomic<float> frequency_{440.0f};
    std::atomic<float> amplitude_{0.25f};
    std::atomic<bool> enabled_{false};
};

}  // namespace chips

#endif  // CHIPS_SINE_GENERATOR_HPP
