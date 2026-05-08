// ChorusModule.hpp — chorus stereo simple: delay corto modulado por LFO sine.

#ifndef CHIPS_CHORUS_MODULE_HPP
#define CHIPS_CHORUS_MODULE_HPP

#include "IModule.hpp"

#include <cstdint>
#include <vector>

namespace chips {

class ChorusModule : public IModule {
public:
    enum Param : uint32_t {
        ParamRate = 0,    // Hz 0.05..5
        ParamDepth = 1,   // 0..1 (modula amount del delay)
        ParamMix = 2,     // 0..1 dry/wet
    };

    ChorusModule();

    static void forceLink();

    const char* typeId() const override { return "chorus"; }
    void prepare(double sampleRate, int maxFrames) override;
    void reset() override;
    void process(const ProcessContext& ctx) override;
    void handleParameterChange(uint32_t paramId, float value) override;

    int numAudioInputs() const override { return 2; }
    int numAudioOutputs() const override { return 2; }

    int numParameters() const override;
    ParamSpec parameterAt(int index) const override;

private:
    static constexpr float kBaseDelayMs = 12.0f;
    static constexpr float kDepthMs = 6.0f;

    double sampleRate_ = 48000.0;
    float rateHz_ = 0.6f;
    float depth_ = 0.5f;
    float mix_ = 0.5f;

    std::vector<float> bufferL_;
    std::vector<float> bufferR_;
    int writeIndex_ = 0;
    double phase_ = 0.0;
};

}  // namespace chips

#endif  // CHIPS_CHORUS_MODULE_HPP
