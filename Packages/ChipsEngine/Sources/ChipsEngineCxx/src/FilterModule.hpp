// FilterModule.hpp — biquad standalone (LP/HP/BP) stereo. RBJ cookbook.

#ifndef CHIPS_FILTER_MODULE_HPP
#define CHIPS_FILTER_MODULE_HPP

#include "IModule.hpp"

#include <cstdint>

namespace chips {

class FilterModule : public IModule {
public:
    enum Mode : int {
        ModeLowPass = 0,
        ModeHighPass = 1,
        ModeBandPass = 2,
    };

    enum Param : uint32_t {
        ParamMode = 0,       // 0=LP, 1=HP, 2=BP (entero codificado en float)
        ParamCutoff = 1,     // Hz 20..18000
        ParamResonance = 2,  // Q 0.5..18
    };

    FilterModule();

    static void forceLink();

    const char* typeId() const override { return "filter"; }
    void prepare(double sampleRate, int maxFrames) override;
    void reset() override;
    void process(const ProcessContext& ctx) override;
    void handleParameterChange(uint32_t paramId, float value) override;

    int numAudioInputs() const override { return 2; }
    int numAudioOutputs() const override { return 2; }

    int numParameters() const override;
    ParamSpec parameterAt(int index) const override;

private:
    void recompute();

    double sampleRate_ = 48000.0;
    int mode_ = ModeLowPass;
    float cutoffHz_ = 2000.0f;
    float q_ = 0.707f;

    float a0_ = 1, a1_ = 0, a2_ = 0;
    float b1_ = 0, b2_ = 0;
    float zL1_ = 0, zL2_ = 0;
    float zR1_ = 0, zR2_ = 0;
};

}  // namespace chips

#endif  // CHIPS_FILTER_MODULE_HPP
