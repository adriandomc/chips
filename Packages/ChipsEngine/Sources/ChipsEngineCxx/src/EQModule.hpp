// EQModule.hpp — 3-band EQ stereo (low shelf + peaking mid + high shelf).
// RBJ cookbook biquads. RT-safe.

#ifndef CHIPS_EQ_MODULE_HPP
#define CHIPS_EQ_MODULE_HPP

#include "IModule.hpp"

#include <cstdint>

namespace chips {

class EQModule : public IModule {
public:
    enum Param : uint32_t {
        ParamLowGain = 0,    // dB -18..+18
        ParamLowFreq = 1,    // Hz 50..500
        ParamMidGain = 2,    // dB -18..+18
        ParamMidFreq = 3,    // Hz 200..5000
        ParamMidQ = 4,       // 0.5..8
        ParamHighGain = 5,   // dB -18..+18
        ParamHighFreq = 6,   // Hz 2000..16000
    };

    EQModule();

    static void forceLink();

    const char* typeId() const override { return "eq"; }
    void prepare(double sampleRate, int maxFrames) override;
    void reset() override;
    void process(const ProcessContext& ctx) override;
    void handleParameterChange(uint32_t paramId, float value) override;

    int numAudioInputs() const override { return 2; }
    int numAudioOutputs() const override { return 2; }

    int numParameters() const override;
    ParamSpec parameterAt(int index) const override;

private:
    struct Biquad {
        float a0 = 1.0f, a1 = 0.0f, a2 = 0.0f, b1 = 0.0f, b2 = 0.0f;
        float zL1 = 0.0f, zL2 = 0.0f;
        float zR1 = 0.0f, zR2 = 0.0f;
        float processL(float x);
        float processR(float x);
        void reset();
    };

    void recomputeAll();
    static void computeLowShelf(Biquad& bq, double sampleRate, float freqHz, float gainDb);
    static void computeHighShelf(Biquad& bq, double sampleRate, float freqHz, float gainDb);
    static void computePeaking(Biquad& bq, double sampleRate, float freqHz, float q, float gainDb);

    double sampleRate_ = 48000.0;

    float lowGainDb_ = 0.0f;
    float lowFreqHz_ = 200.0f;
    float midGainDb_ = 0.0f;
    float midFreqHz_ = 1000.0f;
    float midQ_ = 1.0f;
    float highGainDb_ = 0.0f;
    float highFreqHz_ = 6000.0f;

    Biquad low_;
    Biquad mid_;
    Biquad high_;
};

}  // namespace chips

#endif  // CHIPS_EQ_MODULE_HPP
