// CompressorModule.hpp — feed-forward stereo compressor con envelope one-pole.

#ifndef CHIPS_COMPRESSOR_MODULE_HPP
#define CHIPS_COMPRESSOR_MODULE_HPP

#include "IModule.hpp"

#include <cstdint>

namespace chips {

class CompressorModule : public IModule {
public:
    enum Param : uint32_t {
        ParamThreshold = 0,  // amplitud lineal 0.01..1.0 (default 0.5)
        ParamRatio = 1,      // 1..20 (default 4)
        ParamAttack = 2,     // ms 0.1..200 (default 5)
        ParamRelease = 3,    // ms 10..1000 (default 100)
        ParamMakeup = 4,     // gain lineal 1..8 (default 1)
    };

    CompressorModule();

    static void forceLink();

    const char* typeId() const override { return "compressor"; }
    void prepare(double sampleRate, int maxFrames) override;
    void reset() override;
    void process(const ProcessContext& ctx) override;
    void handleParameterChange(uint32_t paramId, float value) override;

    int numAudioInputs() const override { return 2; }
    int numAudioOutputs() const override { return 2; }

    int numParameters() const override;
    ParamSpec parameterAt(int index) const override;

private:
    void recomputeCoefficients();

    double sampleRate_ = 48000.0;
    float threshold_ = 0.5f;
    float ratio_ = 4.0f;
    float attackMs_ = 5.0f;
    float releaseMs_ = 100.0f;
    float makeup_ = 1.0f;

    float attackCoeff_ = 0.0f;
    float releaseCoeff_ = 0.0f;

    float envelope_ = 0.0f;  // estado del detector
};

}  // namespace chips

#endif  // CHIPS_COMPRESSOR_MODULE_HPP
