// TestSourceModule.hpp — fuente determinística para tests offline.
// Salida = secuencia ramp normalizada en [-1,1] con período `period` muestras.

#ifndef CHIPS_TEST_SOURCE_MODULE_HPP
#define CHIPS_TEST_SOURCE_MODULE_HPP

#include "IModule.hpp"

#include <cstdint>

namespace chips {

class TestSourceModule : public IModule {
public:
    explicit TestSourceModule(int period = 64, int channels = 1)
        : period_(period < 1 ? 1 : period), channels_(channels < 1 ? 1 : channels) {}

    static void forceLink();

    const char* typeId() const override { return "test_source"; }
    void prepare(double /*sampleRate*/, int /*maxFrames*/) override { phase_ = 0; }
    void reset() override { phase_ = 0; }
    void handleParameterChange(uint32_t /*paramId*/, float /*value*/) override {}
    void process(const ProcessContext& ctx) override;

    int numAudioInputs() const override { return 0; }
    int numAudioOutputs() const override { return channels_; }

private:
    int period_;
    int channels_;
    int phase_ = 0;
};

}  // namespace chips

#endif  // CHIPS_TEST_SOURCE_MODULE_HPP
