// MixerModule.hpp — mixer paramétrico con N canales stereo. Cada canal tiene
// gain, pan y mute. Suma a un master stereo. RT-safe.

#ifndef CHIPS_MIXER_MODULE_HPP
#define CHIPS_MIXER_MODULE_HPP

#include "IModule.hpp"

#include <cstdint>
#include <string>
#include <vector>

namespace chips {

class MixerModule : public IModule {
public:
    /// Límite duro razonable para evitar grafos absurdos. R5+ podría subirlo.
    static constexpr int kMaxChannels = 64;

    /// paramId = (channel << 8) | kind.
    enum ParamKind : uint32_t {
        Gain = 0,
        Pan = 1,
        Mute = 2,
    };

    static uint32_t paramId(int channel, ParamKind kind) {
        return (static_cast<uint32_t>(channel) << 8) | static_cast<uint32_t>(kind);
    }

    /// `numChannels` se clampea a [1, kMaxChannels]. Default 8 (concuerda con
    /// la cantidad de strips que la UI muestra). El factory del registry usa
    /// el constructor por defecto; serializaciones con otro número se respetan
    /// si el ProjectGraph almacena un parámetro `numChannels` (R5+).
    explicit MixerModule(int numChannels = 8);

    static void forceLink();

    const char* typeId() const override { return "mixer"; }
    void prepare(double sampleRate, int maxFrames) override;
    void reset() override;
    void process(const ProcessContext& ctx) override;
    void handleParameterChange(uint32_t paramId, float value) override;

    int numAudioInputs() const override { return numChannels_ * 2; }
    int numAudioOutputs() const override { return 2; }

    int numParameters() const override { return static_cast<int>(paramSpecs_.size()); }
    ParamSpec parameterAt(int index) const override;

    int numChannels() const { return numChannels_; }

private:
    struct Channel {
        float gain = 1.0f;
        float pan = 0.0f;
        bool muted = false;
    };

    int numChannels_;
    std::vector<Channel> channels_;
    /// Storage estable de los names de los specs ("ch0_gain", etc.). Reservado
    /// con la capacidad final en el constructor para que `c_str()` no se invalide.
    std::vector<std::string> paramNameStorage_;
    std::vector<ParamSpec> paramSpecs_;
};

}  // namespace chips

#endif  // CHIPS_MIXER_MODULE_HPP
