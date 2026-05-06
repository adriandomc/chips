// IModule.hpp — interfaz de módulo DSP en el grafo de Chips.
// RT-safety estricta en process(): cero alloc, cero locks, cero Obj-C/Swift.

#ifndef CHIPS_IMODULE_HPP
#define CHIPS_IMODULE_HPP

#include <cstdint>

namespace chips {

/// Contexto de proceso pasado a IModule::process. Las pointers son válidas
/// solo durante la llamada y apuntan a buffers dentro del BufferPool del Graph.
struct ProcessContext {
    const float* const* audioIn;     // [numAudioIn][frames]
    float* const* audioOut;          // [numAudioOut][frames]
    int numAudioIn;
    int numAudioOut;
    int frames;
    double sampleRate;
    int64_t tickPosition;            // PPQ ticks desde el inicio del transport
    double tempoBpm;
};

/// Interfaz base de cualquier módulo que vive en el grafo.
class IModule {
public:
    virtual ~IModule() = default;

    /// Llamado desde control thread antes de empezar audio. Permite alocaciones.
    virtual void prepare(double sampleRate, int maxFrames) = 0;

    /// Llamado desde control thread para resetear estado interno (sin realloc).
    virtual void reset() = 0;

    /// Llamado desde el audio thread por cada bloque. RT-safe estricto.
    virtual void process(const ProcessContext& ctx) = 0;

    /// Aplicar cambio de parámetro. Llamado desde el audio thread (drain de SPSC).
    /// La implementación NO debe alocar ni bloquear.
    virtual void handleParameterChange(uint32_t paramId, float value) = 0;

    /// Especificación de I/O. Estable durante la vida del módulo.
    virtual int numAudioInputs() const = 0;
    virtual int numAudioOutputs() const = 0;
};

}  // namespace chips

#endif  // CHIPS_IMODULE_HPP
