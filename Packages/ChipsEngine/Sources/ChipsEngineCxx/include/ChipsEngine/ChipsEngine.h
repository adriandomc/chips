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

#ifdef __cplusplus
}
#endif

#endif /* CHIPS_ENGINE_H */
