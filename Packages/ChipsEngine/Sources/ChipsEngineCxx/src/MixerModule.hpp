// MixerModule.hpp — mixer simple con N canales stereo. Cada canal tiene
// gain, pan y mute. Suma a un master stereo. RT-safe.

#ifndef CHIPS_MIXER_MODULE_HPP
#define CHIPS_MIXER_MODULE_HPP

#include "IModule.hpp"

#include <array>
#include <cstdint>

namespace chips {

class MixerModule : public IModule {
public:
    static constexpr int kMaxChannels = 4;

    /// paramId = (channel << 8) | kind. kind = 0:gain, 1:pan, 2:mute.
    enum ParamKind : uint32_t {
        Gain = 0,
        Pan = 1,
        Mute = 2,
    };

    static uint32_t paramId(int channel, ParamKind kind) {
        return (static_cast<uint32_t>(channel) << 8) | static_cast<uint32_t>(kind);
    }

    MixerModule();

    void prepare(double sampleRate, int maxFrames) override;
    void reset() override;
    void process(const ProcessContext& ctx) override;
    void handleParameterChange(uint32_t paramId, float value) override;

    int numAudioInputs() const override { return kMaxChannels * 2; }
    int numAudioOutputs() const override { return 2; }

private:
    struct Channel {
        float gain = 1.0f;
        float pan = 0.0f;
        bool muted = false;
    };
    std::array<Channel, kMaxChannels> channels_{};
};

}  // namespace chips

#endif  // CHIPS_MIXER_MODULE_HPP
