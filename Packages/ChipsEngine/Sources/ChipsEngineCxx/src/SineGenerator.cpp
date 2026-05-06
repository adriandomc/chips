// SineGenerator.cpp — implementación.

#include "SineGenerator.hpp"

#include <cmath>
#include <cstring>

namespace chips {

namespace {
constexpr double kTwoPi = 6.28318530717958647692;
}  // namespace

void SineGenerator::prepare(double sampleRate) {
    sampleRate_ = sampleRate > 0.0 ? sampleRate : 48000.0;
    phase_ = 0.0;
}

void SineGenerator::setFrequency(float hz) {
    if (hz < 0.0f) {
        hz = 0.0f;
    }
    frequency_.store(hz, std::memory_order_relaxed);
}

void SineGenerator::setEnabled(bool enabled) {
    enabled_.store(enabled, std::memory_order_relaxed);
}

bool SineGenerator::isEnabled() const {
    return enabled_.load(std::memory_order_relaxed);
}

float SineGenerator::frequency() const {
    return frequency_.load(std::memory_order_relaxed);
}

void SineGenerator::process(float* interleavedStereoOut, int frames) {
    if (interleavedStereoOut == nullptr || frames <= 0) {
        return;
    }

    if (!enabled_.load(std::memory_order_relaxed)) {
        std::memset(interleavedStereoOut, 0, static_cast<size_t>(frames) * 2 * sizeof(float));
        return;
    }

    const float freq = frequency_.load(std::memory_order_relaxed);
    const double phaseInc = (kTwoPi * static_cast<double>(freq)) / sampleRate_;

    double phase = phase_;
    for (int i = 0; i < frames; ++i) {
        const float sample = static_cast<float>(std::sin(phase)) * 0.25f;  // -12 dBFS
        interleavedStereoOut[i * 2] = sample;
        interleavedStereoOut[i * 2 + 1] = sample;
        phase += phaseInc;
        if (phase >= kTwoPi) {
            phase -= kTwoPi;
        }
    }
    phase_ = phase;
}

}  // namespace chips
