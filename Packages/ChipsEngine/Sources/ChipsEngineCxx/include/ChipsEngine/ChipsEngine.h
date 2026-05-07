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

// Identificadores de tipo de nodo built-in (estables, comparten string con el
// `ModuleRegistry`). Para listar dinámicamente los tipos disponibles, usar
// `chips_engine_registered_type_count` / `_at`.
#define CHIPS_NODE_TYPE_SINE "sine"
#define CHIPS_NODE_TYPE_PASSTHROUGH "passthrough"
#define CHIPS_NODE_TYPE_TEST_SOURCE "test_source"
#define CHIPS_NODE_TYPE_ADDITIVE_SYNTH "additive_synth"
#define CHIPS_NODE_TYPE_MIXER "mixer"
#define CHIPS_NODE_TYPE_DELAY "delay"
#define CHIPS_NODE_TYPE_REVERB "reverb"

/// Metadata declarativa de un parámetro de un módulo. Permite a la UI generar
/// controles sin conocer el tipo concreto. `name` y `unit` apuntan a memoria
/// estática del módulo y son válidos durante toda la vida del proceso.
typedef struct ChipsParamSpec {
    uint32_t param_id;
    const char* name;
    const char* unit;
    float min_value;
    float max_value;
    float default_value;
} ChipsParamSpec;

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

ChipsNodeId chips_engine_add_node(ChipsEngineHandle* engine, const char* type_id);
bool chips_engine_remove_node(ChipsEngineHandle* engine, ChipsNodeId node);
bool chips_engine_connect(ChipsEngineHandle* engine,
                          ChipsNodeId src, int src_port,
                          ChipsNodeId dst, int dst_port);
bool chips_engine_disconnect(ChipsEngineHandle* engine,
                             ChipsNodeId src, int src_port,
                             ChipsNodeId dst, int dst_port);
void chips_engine_set_output_node(ChipsEngineHandle* engine, ChipsNodeId node);
bool chips_engine_compile(ChipsEngineHandle* engine);

// ---- Eventos (RT-safe vía SPSC) ----

bool chips_engine_set_parameter(ChipsEngineHandle* engine, ChipsNodeId node, uint32_t param_id, float value);
bool chips_engine_send_note_on(ChipsEngineHandle* engine, ChipsNodeId node, int midi, float velocity);
bool chips_engine_send_note_off(ChipsEngineHandle* engine, ChipsNodeId node, int midi);

// ---- Introspección de módulos ----

/// Devuelve el typeId del nodo (string estable). NULL si el nodo no existe.
const char* chips_engine_node_type_id(ChipsEngineHandle* engine, ChipsNodeId node);

/// Número de parámetros expuestos por el módulo. 0 si el nodo no existe o no
/// declara parámetros (ej. PassthroughModule).
int chips_engine_node_param_count(ChipsEngineHandle* engine, ChipsNodeId node);

/// Llena `out` con la spec del parámetro `index` del nodo. Devuelve false si
/// el nodo no existe, el índice está fuera de rango, o `out` es NULL.
bool chips_engine_node_param_at(ChipsEngineHandle* engine, ChipsNodeId node, int index, ChipsParamSpec* out);

/// Número de tipos registrados en el `ModuleRegistry` capturado al crear el
/// engine. Estable durante la vida del engine.
int chips_engine_registered_type_count(ChipsEngineHandle* engine);

/// typeId registrado en el índice dado (0..count-1). NULL si fuera de rango.
const char* chips_engine_registered_type_at(ChipsEngineHandle* engine, int index);

#ifdef __cplusplus
}
#endif

#endif /* CHIPS_ENGINE_H */
