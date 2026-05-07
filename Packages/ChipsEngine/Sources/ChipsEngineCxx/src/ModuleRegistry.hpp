// ModuleRegistry.hpp — registry self-registering de tipos de IModule.
// Cada módulo se auto-registra desde un static initializer en su .cpp,
// eliminando el switch/if-else manual en `makeModuleFromTypeId`.
//
// Para que el linker NO descarte los static initializers en static libs
// (Swift Package Manager target), cada `kRegistered` debe llevar
// `__attribute__((used))` y/o haber alguna referencia desde código que sí
// se enlace. Como red de seguridad, `ChipsEngine.cpp::touchAllModules()`
// hace una referencia explícita a cada tipo conocido.

#ifndef CHIPS_MODULE_REGISTRY_HPP
#define CHIPS_MODULE_REGISTRY_HPP

#include "IModule.hpp"

#include <functional>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

namespace chips {

class ModuleRegistry {
public:
    using Factory = std::function<std::unique_ptr<IModule>()>;

    /// Singleton estable durante la vida del proceso.
    static ModuleRegistry& instance();

    /// Registra un tipo. Si ya existía un factory para `typeId`, devuelve
    /// false sin sobreescribir (registros duplicados son siempre programmer error).
    bool register_(const std::string& typeId, Factory factory);

    /// Crea una instancia del tipo registrado. Devuelve nullptr si no existe.
    std::unique_ptr<IModule> create(const std::string& typeId) const;

    /// Lista de typeIds registrados (orden de inserción no garantizado).
    std::vector<std::string> registeredTypes() const;

    /// Para tests / introspección.
    bool isRegistered(const std::string& typeId) const;
    int count() const;

private:
    ModuleRegistry() = default;
    ModuleRegistry(const ModuleRegistry&) = delete;
    ModuleRegistry& operator=(const ModuleRegistry&) = delete;

    std::unordered_map<std::string, Factory> factories_;
};

}  // namespace chips

#endif  // CHIPS_MODULE_REGISTRY_HPP
