// SpscQueue.hpp — cola single-producer single-consumer lock-free, ring buffer
// con capacidad fija (potencia de 2). Diseñada para parámetros control->audio.

#ifndef CHIPS_SPSC_QUEUE_HPP
#define CHIPS_SPSC_QUEUE_HPP

#include <array>
#include <atomic>
#include <cstddef>

namespace chips {

template <typename T, size_t Capacity> class SpscQueue {
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be power of two");

public:
    /// Productor (control thread). Devuelve false si la cola está llena.
    bool push(const T& item) {
        const size_t tail = tail_.load(std::memory_order_relaxed);
        const size_t next = (tail + 1) & kMask;
        if (next == head_.load(std::memory_order_acquire)) {
            return false;  // full
        }
        buffer_[tail] = item;
        tail_.store(next, std::memory_order_release);
        return true;
    }

    /// Consumidor (audio thread). Devuelve false si la cola está vacía.
    bool pop(T& out) {
        const size_t head = head_.load(std::memory_order_relaxed);
        if (head == tail_.load(std::memory_order_acquire)) {
            return false;  // empty
        }
        out = buffer_[head];
        head_.store((head + 1) & kMask, std::memory_order_release);
        return true;
    }

    bool empty() const { return head_.load(std::memory_order_acquire) == tail_.load(std::memory_order_acquire); }

private:
    static constexpr size_t kMask = Capacity - 1;
    alignas(64) std::atomic<size_t> head_{0};  // consumer index
    alignas(64) std::atomic<size_t> tail_{0};  // producer index
    std::array<T, Capacity> buffer_{};
};

}  // namespace chips

#endif  // CHIPS_SPSC_QUEUE_HPP
