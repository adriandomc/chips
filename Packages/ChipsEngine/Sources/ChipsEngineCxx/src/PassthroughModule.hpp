// PassthroughModule.hpp — copia entrada a salida. Útil para tests del grafo.

#ifndef CHIPS_PASSTHROUGH_MODULE_HPP
#define CHIPS_PASSTHROUGH_MODULE_HPP

#include "IModule.hpp"

#include <cstdint>

namespace chips {

class PassthroughModule : public IModule {
public:
    explicit PassthroughModule(int channels = 1) : channels_(channels < 1 ? 1 : channels) {}

    static void forceLink();

    const char* typeId() const override { return "passthrough"; }
    void prepare(double /*sampleRate*/, int /*maxFrames*/) override {}
    void reset() override {}
    void handleParameterChange(uint32_t /*paramId*/, float /*value*/) override {}
    void process(const ProcessContext& ctx) override;

    int numAudioInputs() const override { return channels_; }
    int numAudioOutputs() const override { return channels_; }

private:
    int channels_;
};

}  // namespace chips

#endif  // CHIPS_PASSTHROUGH_MODULE_HPP
