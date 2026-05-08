// DistortionModule.hpp — soft-clip distortion stereo (tanh).

#ifndef CHIPS_DISTORTION_MODULE_HPP
#define CHIPS_DISTORTION_MODULE_HPP

#include "IModule.hpp"

#include <cstdint>

namespace chips {

class DistortionModule : public IModule {
public:
    enum Param : uint32_t {
        ParamDrive = 0,    // 1..50 (gain pre-clip)
        ParamMix = 1,      // 0..1 dry/wet
        ParamLevel = 2,    // 0..1 output trim
    };

    DistortionModule();

    static void forceLink();

    const char* typeId() const override { return "distortion"; }
    void prepare(double sampleRate, int maxFrames) override;
    void reset() override;
    void process(const ProcessContext& ctx) override;
    void handleParameterChange(uint32_t paramId, float value) override;

    int numAudioInputs() const override { return 2; }
    int numAudioOutputs() const override { return 2; }

    int numParameters() const override;
    ParamSpec parameterAt(int index) const override;

private:
    float drive_ = 4.0f;
    float mix_ = 1.0f;
    float level_ = 0.7f;
};

}  // namespace chips

#endif  // CHIPS_DISTORTION_MODULE_HPP
