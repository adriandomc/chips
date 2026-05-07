// ModuleRegistry.cpp

#include "ModuleRegistry.hpp"

namespace chips {

ModuleRegistry& ModuleRegistry::instance() {
    static ModuleRegistry registry;
    return registry;
}

bool ModuleRegistry::register_(const std::string& typeId, Factory factory) {
    if (typeId.empty() || factory == nullptr) {
        return false;
    }
    auto [it, inserted] = factories_.emplace(typeId, std::move(factory));
    (void)it;
    return inserted;
}

std::unique_ptr<IModule> ModuleRegistry::create(const std::string& typeId) const {
    auto it = factories_.find(typeId);
    if (it == factories_.end()) {
        return nullptr;
    }
    return it->second();
}

std::vector<std::string> ModuleRegistry::registeredTypes() const {
    std::vector<std::string> out;
    out.reserve(factories_.size());
    for (const auto& [typeId, factory] : factories_) {
        (void)factory;
        out.push_back(typeId);
    }
    return out;
}

bool ModuleRegistry::isRegistered(const std::string& typeId) const {
    return factories_.find(typeId) != factories_.end();
}

int ModuleRegistry::count() const {
    return static_cast<int>(factories_.size());
}

}  // namespace chips
