// ReverbModule.hpp — reverb estilo Schroeder con 4 comb filters paralelos
// + 2 allpass en serie. Stereo.

#ifndef CHIPS_REVERB_MODULE_HPP
#define CHIPS_REVERB_MODULE_HPP

#include "IModule.hpp"

#include <array>
#include <cstdint>
#include <vector>

namespace chips {

class ReverbModule : public IModule {
public:
    enum Param : uint32_t {
        ParamRoomSize = 0,  // 0..1 (afecta feedback de combs)
        ParamDamping = 1,   // 0..1 (low-pass en feedback)
        ParamWet = 2,       // 0..1
    };

    static constexpr int kNumCombs = 4;
    static constexpr int kNumAllpass = 2;

    ReverbModule() = default;

    void prepare(double sampleRate, int maxFrames) override;
    void reset() override;
    void process(const ProcessContext& ctx) override;
    void handleParameterChange(uint32_t paramId, float value) override;

    int numAudioInputs() const override { return 2; }
    int numAudioOutputs() const override { return 2; }

private:
    struct CombFilter {
        std::vector<float> buffer;
        int writeIdx = 0;
        float feedback = 0.84f;
        float damping = 0.2f;
        float prev = 0.0f;
        float process(float input);
        void reset();
    };
    struct AllpassFilter {
        std::vector<float> buffer;
        int writeIdx = 0;
        float feedback = 0.5f;
        float process(float input);
        void reset();
    };

    void updateInternalParams();

    std::array<CombFilter, kNumCombs> combs_{};
    std::array<AllpassFilter, kNumAllpass> allpass_{};

    double sampleRate_ = 48000.0;
    float roomSize_ = 0.7f;
    float damping_ = 0.2f;
    float wet_ = 0.3f;
};

}  // namespace chips

#endif  // CHIPS_REVERB_MODULE_HPP
