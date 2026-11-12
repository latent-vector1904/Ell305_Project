#pragma once

#include <array>
#include <cstdint>
#include <ostream>
#include <string>
#include <vector>

// Same geometry as the board images.
// 256-byte memory, 16-byte cache, 4-byte lines, read only.
// A memory byte equals its address. A hit takes 2 enable cycles, a miss 9.

enum class Kind { Direct, TwoWay, Lru };

struct Stats {
    int accesses = 0;
    int hits = 0;
    int misses = 0;
    int cold = 0;
    int replacements = 0;
    long cycles = 0;
};

struct Event {
    int address = 0;
    bool hit = false;
    int data = 0;
    int tag = 0;
    int index = 0;
    int offset = 0;
    int way = -1;
    int cycles = 0;
    bool cold = false;
    std::string place;
};

struct Slot {
    std::string name;
    bool valid = false;
    int tag = 0;
    int base = 0;
    std::array<uint8_t, 4> bytes{};
    std::string mark;
    bool last = false;
    int last_offset = -1;
};

class Cache {
public:
    explicit Cache(Kind kind);

    Kind kind() const { return kind_; }
    const char* id() const;
    const char* name() const;
    const Stats& stats() const { return stats_; }
    const std::vector<Event>& log() const { return log_; }
    const std::vector<int>& history() const { return history_; }

    void reset();
    Event access(int address);
    std::vector<Slot> slots() const;
    void write_json(std::ostream& out) const;

private:
    struct Line {
        bool valid = false;
        int tag = 0;
        std::array<uint8_t, 4> bytes{};
    };

    void fill(Line& line, int base, int tag);
    void touch_lru(int way);
    int pick_lru() const;
    void remember(const Event& event);

    Kind kind_;
    Stats stats_;
    std::vector<Event> log_;
    std::vector<int> history_;
    std::array<bool, 64> seen_{};

    std::array<Line, 4> direct_{};
    std::array<std::array<Line, 2>, 2> sets_{};
    std::array<int, 2> lru_bit_{};
    std::array<Line, 4> fully_{};
    std::array<int, 4> age_{};

    int last_slot_ = -1;
    int last_offset_ = -1;
};

std::string state_json(const std::array<Cache, 3>& caches);
bool same_history(const std::array<Cache, 3>& caches);
