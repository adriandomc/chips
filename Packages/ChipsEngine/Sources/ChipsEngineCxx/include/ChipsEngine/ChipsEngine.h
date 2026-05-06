// ChipsEngine.h — C ABI público del motor DSP.
// Este header se importa desde Swift; mantenerlo C-puro (sin C++).

#ifndef CHIPS_ENGINE_H
#define CHIPS_ENGINE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ChipsEngineHandle ChipsEngineHandle;

/// Crea un nuevo motor con la sample rate y tamaño máximo de bloque indicados.
/// Retorna NULL en caso de fallo de allocación.
ChipsEngineHandle* chips_engine_create(double sample_rate, int max_frames);

/// Libera un motor previamente creado por chips_engine_create.
void chips_engine_destroy(ChipsEngineHandle* engine);

/// Renderiza `frames` muestras en el buffer de salida intercalado stereo (L,R,L,R,...).
/// Debe llamarse desde el audio thread. RT-safe.
void chips_engine_render(ChipsEngineHandle* engine, float* interleaved_stereo_out, int frames);

/// Versión del motor como cadena C-string estática.
const char* chips_engine_version(void);

// ---- Sine generator (módulo de prueba para M1) ----

/// Establece la frecuencia del generador sinusoidal interno (Hz).
/// Llamable desde cualquier thread; aplicado en el siguiente buffer.
void chips_engine_set_sine_frequency(ChipsEngineHandle* engine, float hz);

/// Activa o desactiva el generador sinusoidal. Desactivado = silencio.
void chips_engine_set_sine_enabled(ChipsEngineHandle* engine, bool enabled);

/// Devuelve true si el generador sinusoidal está activo.
bool chips_engine_is_sine_enabled(const ChipsEngineHandle* engine);

// ---- Métricas ----

/// Carga DSP (0.0 = idle, 1.0 = saturado). Suavizada por EMA.
float chips_engine_dsp_load(const ChipsEngineHandle* engine);

/// Sample rate efectivo configurado en el motor.
double chips_engine_sample_rate(const ChipsEngineHandle* engine);

#ifdef __cplusplus
}
#endif

#endif /* CHIPS_ENGINE_H */
