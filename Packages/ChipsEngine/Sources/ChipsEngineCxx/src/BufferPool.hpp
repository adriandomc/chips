// BufferPool.hpp — pool pre-alocado de buffers de audio compartidos por el grafo.
// Las alocaciones ocurren solo en prepare() (control thread). buffer() es RT-safe.

#ifndef CHIPS_BUFFER_POOL_HPP
#define CHIPS_BUFFER_POOL_HPP

#include <cstring>
#include <vector>

namespace chips {

class BufferPool {
public:
    void prepare(int numBuffers, int maxFrames) {
        buffers_.assign(static_cast<size_t>(numBuffers), std::vector<float>(static_cast<size_t>(maxFrames), 0.0f));
        maxFrames_ = maxFrames;
    }

    int size() const { return static_cast<int>(buffers_.size()); }
    int maxFrames() const { return maxFrames_; }

    float* buffer(int index) {
        if (index < 0 || index >= static_cast<int>(buffers_.size())) {
            return nullptr;
        }
        return buffers_[static_cast<size_t>(index)].data();
    }

    void clear(int index, int frames) {
        if (auto* b = buffer(index); b != nullptr) {
            std::memset(b, 0, static_cast<size_t>(frames) * sizeof(float));
        }
    }

private:
    std::vector<std::vector<float>> buffers_;
    int maxFrames_ = 0;
};

}  // namespace chips

#endif  // CHIPS_BUFFER_POOL_HPP
