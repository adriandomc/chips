// DspLoadTracker.hpp — métrica de carga DSP (% del buffer time gastado en render).
// RT-safe: solo lectura/escritura atómica. Lock-free en arquitecturas modernas.

#ifndef CHIPS_DSP_LOAD_TRACKER_HPP
#define CHIPS_DSP_LOAD_TRACKER_HPP

#include <atomic>
#include <chrono>

namespace chips {

class DspLoadTracker {
public:
    using Clock = std::chrono::steady_clock;

    // Llamada al inicio de cada render.
    Clock::time_point begin() { return Clock::now(); }

    // Llamada al terminar el render. Calcula carga = render_time / buffer_time.
    void end(Clock::time_point startTime, int frames, double sampleRate) {
        if (frames <= 0 || sampleRate <= 0.0) {
            return;
        }
        const auto elapsed = std::chrono::duration<double>(Clock::now() - startTime).count();
        const double bufferDuration = static_cast<double>(frames) / sampleRate;
        const float load = bufferDuration > 0.0 ? static_cast<float>(elapsed / bufferDuration) : 0.0f;
        // EMA simple para suavizar (alpha=0.1).
        const float prev = load_.load(std::memory_order_relaxed);
        const float smoothed = prev * 0.9f + load * 0.1f;
        load_.store(smoothed, std::memory_order_relaxed);
    }

    // Carga actual como fracción 0..1+ (puede pasarse de 1.0 si hay overrun).
    float load() const { return load_.load(std::memory_order_relaxed); }

    void reset() { load_.store(0.0f, std::memory_order_relaxed); }

private:
    std::atomic<float> load_{0.0f};
};

}  // namespace chips

#endif  // CHIPS_DSP_LOAD_TRACKER_HPP
