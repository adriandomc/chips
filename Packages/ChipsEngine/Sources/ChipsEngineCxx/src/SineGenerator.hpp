// SineGenerator.hpp — generador de sinusoide stereo. RT-safe.

#ifndef CHIPS_SINE_GENERATOR_HPP
#define CHIPS_SINE_GENERATOR_HPP

#include <atomic>

namespace chips {

class SineGenerator {
public:
    SineGenerator() = default;

    // Llamado desde control thread, antes de comenzar audio.
    void prepare(double sampleRate);

    // Cambia frecuencia de forma atómica (puede llamarse desde control thread).
    void setFrequency(float hz);

    // Activa/desactiva. Cuando está desactivado emite silencio (sin discontinuidad de fase).
    void setEnabled(bool enabled);

    bool isEnabled() const;
    float frequency() const;

    // RT-safe. Escribe `frames` muestras intercaladas L,R en `out`.
    void process(float* interleavedStereoOut, int frames);

private:
    double sampleRate_ = 48000.0;
    double phase_ = 0.0;
    std::atomic<float> frequency_{440.0f};
    std::atomic<bool> enabled_{false};
};

}  // namespace chips

#endif  // CHIPS_SINE_GENERATOR_HPP
