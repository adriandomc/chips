// IModule.hpp — interfaz de módulo DSP en el grafo de Chips.
// RT-safety estricta en process(): cero alloc, cero locks, cero Obj-C/Swift.

#ifndef CHIPS_IMODULE_HPP
#define CHIPS_IMODULE_HPP

#include <cstdint>

namespace chips {

/// Metadata declarativa de un parámetro. Permite a la UI generar controles
/// (knob, slider) sin conocer el tipo de módulo.
///
/// Las cadenas (`name`, `unit`) deben tener vida estática (static string
/// literal o miembro estático del módulo) — no se copian al cruzar la C ABI.
struct ParamSpec {
    uint32_t paramId = 0;
    const char* name = "";
    const char* unit = "";
    float minValue = 0.0f;
    float maxValue = 1.0f;
    float defaultValue = 0.0f;
};

/// Contexto de proceso pasado a IModule::process. Las pointers son válidas
/// solo durante la llamada y apuntan a buffers dentro del BufferPool del Graph.
struct ProcessContext {
    const float* const* audioIn;  // [numAudioIn][frames]
    float* const* audioOut;       // [numAudioOut][frames]
    int numAudioIn;
    int numAudioOut;
    int frames;
    double sampleRate;
    int64_t tickPosition;  // PPQ ticks desde el inicio del transport
    double tempoBpm;
};

/// Interfaz base de cualquier módulo que vive en el grafo.
///
/// Contrato de RT-safety en `process()`: cero alloc, cero locks, cero
/// Obj-C/Swift, cero excepciones. Es responsabilidad del módulo respetarlo;
/// el sistema lo verifica vía realtime-sanitizer en CI sobre tests offline.
class IModule {
public:
    virtual ~IModule() = default;

    /// Identificador estable del tipo. Igual al que se registra en el
    /// `ModuleRegistry` (ej. "additive_synth", "delay", "reverb").
    /// La cadena debe tener vida estática.
    virtual const char* typeId() const = 0;

    /// Llamado desde control thread antes de empezar audio. Permite alocaciones.
    virtual void prepare(double sampleRate, int maxFrames) = 0;

    /// Llamado desde control thread para resetear estado interno (sin realloc).
    virtual void reset() = 0;

    /// Llamado desde el audio thread por cada bloque. RT-safe estricto.
    virtual void process(const ProcessContext& ctx) = 0;

    /// Aplicar cambio de parámetro. Llamado desde el audio thread (drain de SPSC).
    /// La implementación NO debe alocar ni bloquear.
    virtual void handleParameterChange(uint32_t paramId, float value) = 0;

    /// Eventos de nota. Default no-op (efectos los ignoran). Llamados desde el
    /// audio thread igual que handleParameterChange.
    virtual void handleNoteOn(int /*midi*/, float /*velocity*/) {}
    virtual void handleNoteOff(int /*midi*/) {}

    /// Especificación de I/O. Estable durante la vida del módulo.
    virtual int numAudioInputs() const = 0;
    virtual int numAudioOutputs() const = 0;

    /// Metadata de parámetros para UI generada y serialización. Default 0
    /// (módulos sin parámetros expuestos, como PassthroughModule).
    virtual int numParameters() const { return 0; }
    virtual ParamSpec parameterAt(int /*index*/) const { return ParamSpec{}; }
};

}  // namespace chips

#endif  // CHIPS_IMODULE_HPP
