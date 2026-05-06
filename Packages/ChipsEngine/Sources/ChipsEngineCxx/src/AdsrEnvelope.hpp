// AdsrEnvelope.hpp — envelope ADSR lineal. Header-only, RT-safe.
// Llamado desde el audio thread; los setters son llamados por
// handleParameterChange durante el drain del SPSC (mismo thread, sin atómicos).

#ifndef CHIPS_ADSR_ENVELOPE_HPP
#define CHIPS_ADSR_ENVELOPE_HPP

#include <algorithm>

namespace chips {

class AdsrEnvelope {
public:
    enum class Stage { Idle, Attack, Decay, Sustain, Release };

    void prepare(double sampleRate) {
        sampleRate_ = sampleRate > 0 ? sampleRate : 48000.0;
        reset();
    }

    void reset() {
        stage_ = Stage::Idle;
        value_ = 0.0f;
        releaseStart_ = 0.0f;
    }

    void noteOn() { stage_ = Stage::Attack; }

    void noteOff() {
        if (stage_ != Stage::Idle) {
            stage_ = Stage::Release;
            releaseStart_ = value_;
        }
    }

    bool isActive() const { return stage_ != Stage::Idle; }

    // RT-safe: devuelve el siguiente sample del envelope (0..1).
    float process() {
        switch (stage_) {
        case Stage::Idle:
            return 0.0f;
        case Stage::Attack: {
            const float step = 1.0f / std::max(1.0f, attackSeconds_ * static_cast<float>(sampleRate_));
            value_ += step;
            if (value_ >= 1.0f) {
                value_ = 1.0f;
                stage_ = Stage::Decay;
            }
            return value_;
        }
        case Stage::Decay: {
            const float step = (1.0f - sustain_) / std::max(1.0f, decaySeconds_ * static_cast<float>(sampleRate_));
            value_ -= step;
            if (value_ <= sustain_) {
                value_ = sustain_;
                stage_ = Stage::Sustain;
            }
            return value_;
        }
        case Stage::Sustain:
            return value_;
        case Stage::Release: {
            const float step = releaseStart_ / std::max(1.0f, releaseSeconds_ * static_cast<float>(sampleRate_));
            value_ -= step;
            if (value_ <= 0.0f) {
                value_ = 0.0f;
                stage_ = Stage::Idle;
            }
            return value_;
        }
        }
        return 0.0f;
    }

    void setAttack(float seconds) { attackSeconds_ = std::max(0.001f, seconds); }
    void setDecay(float seconds) { decaySeconds_ = std::max(0.001f, seconds); }
    void setSustain(float level) { sustain_ = std::max(0.0f, std::min(1.0f, level)); }
    void setRelease(float seconds) { releaseSeconds_ = std::max(0.001f, seconds); }

private:
    Stage stage_ = Stage::Idle;
    double sampleRate_ = 48000.0;
    float value_ = 0.0f;
    float releaseStart_ = 0.0f;
    float attackSeconds_ = 0.01f;
    float decaySeconds_ = 0.1f;
    float sustain_ = 0.7f;
    float releaseSeconds_ = 0.3f;
};

}  // namespace chips

#endif  // CHIPS_ADSR_ENVELOPE_HPP
