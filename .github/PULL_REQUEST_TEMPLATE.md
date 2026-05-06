## Resumen

<!-- ¿Qué cambia y por qué? Una o dos frases. -->

## Milestone / Ticket

<!-- M0, M1, ... y referencia al ticket si existe. -->

## Checklist (Definition of Done)

### Generales
- [ ] SwiftLint strict + SwiftFormat sin warnings
- [ ] C/C++ con `-Wall -Wextra -Wpedantic` sin warnings nuevos
- [ ] CI verde (build + tests + lint)
- [ ] Cobertura ≥ 70% en lógica pura del módulo tocado
- [ ] CHANGELOG actualizado
- [ ] Documentación pública (DocC) generada para APIs nuevas

### Audio (si toca DSP)
- [ ] RT-safety auditada: 0 alloc / 0 locks / 0 Obj-C-Swift / 0 excepciones en `process()`
- [ ] Probado en iPhone físico (5 min sin underruns)
- [ ] Sin glitches audibles en cambios de parámetros / transport / add-remove
- [ ] Instruments: Time Profiler + Allocations ejecutados, 0 allocations en audio thread
- [ ] Bit-exactness verificada donde aplica
- [ ] Denormals: FTZ/DAZ activos; sin spikes al silenciar
- [ ] MIDI probado con controlador físico y virtual port (si aplica)

### UI (si toca componentes visuales)
- [ ] **Diseño del usuario disponible y referenciado** (sin diseño → no se mergea)
- [ ] Snapshot tests pasan @1x/@2x/@3x
- [ ] 60 fps en iPhone SE 3 verificado con Instruments
- [ ] Multi-touch (≥4 puntos) funcional en knobs/teclado si aplica
- [ ] Estados visuales completos (default, pressed, disabled)

## Test plan

<!-- Pasos manuales / scripts ejecutados -->
