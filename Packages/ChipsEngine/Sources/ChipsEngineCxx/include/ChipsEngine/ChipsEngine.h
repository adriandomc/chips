// ChipsEngine.h — C ABI público del motor DSP.
// Mantener C-puro (sin C++) — se importa desde Swift via modulemap.

#ifndef CHIPS_ENGINE_H
#define CHIPS_ENGINE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ChipsEngineHandle ChipsEngineHandle;

typedef uint32_t ChipsNodeId;
#define CHIPS_INVALID_NODE_ID ((ChipsNodeId)0)

// Identificadores de tipo de nodo (estables).
#define CHIPS_NODE_TYPE_SINE "sine"
#define CHIPS_NODE_TYPE_PASSTHROUGH "passthrough"
#define CHIPS_NODE_TYPE_TEST_SOURCE "test_source"
#define CHIPS_NODE_TYPE_ADDITIVE_SYNTH "additive_synth"

// ---- Engine lifecycle ----

ChipsEngineHandle* chips_engine_create(double sample_rate, int max_frames);
void chips_engine_destroy(ChipsEngineHandle* engine);
const char* chips_engine_version(void);

/// Renderiza `frames` muestras intercaladas stereo (L,R,L,R,...) en el buffer.
/// RT-safe; debe llamarse desde el audio thread.
void chips_engine_render(ChipsEngineHandle* engine, float* interleaved_stereo_out, int frames);

// ---- Métricas ----

float chips_engine_dsp_load(const ChipsEngineHandle* engine);
double chips_engine_sample_rate(const ChipsEngineHandle* engine);

// ---- Grafo dinámico ----

/// Añade un nodo del tipo indicado y devuelve su ID. Retorna 0 si falla.
ChipsNodeId chips_engine_add_node(ChipsEngineHandle* engine, const char* type_id);

/// Elimina un nodo y todas sus conexiones.
bool chips_engine_remove_node(ChipsEngineHandle* engine, ChipsNodeId node);

/// Conecta src.outPort -> dst.inPort. Un input solo puede tener un origen.
bool chips_engine_connect(ChipsEngineHandle* engine, ChipsNodeId src, int src_port, ChipsNodeId dst, int dst_port);

bool chips_engine_disconnect(ChipsEngineHandle* engine, ChipsNodeId src, int src_port, ChipsNodeId dst, int dst_port);

/// Define el nodo cuya salida (puertos 0,1) se enviará al output del engine.
void chips_engine_set_output_node(ChipsEngineHandle* engine, ChipsNodeId node);

/// Compila el grafo: ordena topológicamente, asigna buffers y publica plan
/// al audio thread vía atomic swap. Devuelve false si hay ciclo o config inválida.
bool chips_engine_compile(ChipsEngineHandle* engine);

/// Encola un cambio de parámetro (RT-safe vía SPSC). Devuelve false si la cola
/// está llena. El cambio se aplica antes del próximo render block.
bool chips_engine_set_parameter(ChipsEngineHandle* engine, ChipsNodeId node, uint32_t param_id, float value);

/// Envía un Note On al nodo (instrumento). velocity en [0..1].
bool chips_engine_send_note_on(ChipsEngineHandle* engine, ChipsNodeId node, int midi, float velocity);

/// Envía un Note Off al nodo.
bool chips_engine_send_note_off(ChipsEngineHandle* engine, ChipsNodeId node, int midi);

#ifdef __cplusplus
}
#endif

#endif /* CHIPS_ENGINE_H */
