// DelayModule.hpp — delay stereo con feedback y wet/dry.

#ifndef CHIPS_DELAY_MODULE_HPP
#define CHIPS_DELAY_MODULE_HPP

#include "IModule.hpp"

#include <cstdint>
#include <vector>

namespace chips {

class DelayModule : public IModule {
public:
    enum Param : uint32_t {
        ParamTime = 0,      // seconds
        ParamFeedback = 1,  // 0..0.95
        ParamWet = 2,       // 0..1
    };

    DelayModule() = default;

    static void forceLink();

    const char* typeId() const override { return "delay"; }
    void prepare(double sampleRate, int maxFrames) override;
    void reset() override;
    void process(const ProcessContext& ctx) override;
    void handleParameterChange(uint32_t paramId, float value) override;

    int numAudioInputs() const override { return 2; }
    int numAudioOutputs() const override { return 2; }

    int numParameters() const override;
    ParamSpec parameterAt(int index) const override;

private:
    double sampleRate_ = 48000.0;
    int bufferSize_ = 0;
    int writeIdx_ = 0;
    std::vector<float> bufferL_;
    std::vector<float> bufferR_;
    float timeSeconds_ = 0.35f;
    float feedback_ = 0.4f;
    float wet_ = 0.3f;
};

}  // namespace chips

#endif  // CHIPS_DELAY_MODULE_HPP
