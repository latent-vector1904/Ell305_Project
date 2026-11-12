#include "cache.hpp"

#include <sstream>

namespace {

constexpr int kHitCycles = 2;
constexpr int kMissCycles = 9;
constexpr int kLogLimit = 200;

void json_string(std::ostream& out, const std::string& text) {
    out << '"';
    for (char ch : text) {
        if (ch == '"' || ch == '\\') out << '\\';
        out << ch;
    }
    out << '"';
}

}  // namespace

Cache::Cache(Kind kind) : kind_(kind) { reset(); }

const char* Cache::id() const {
    switch (kind_) {
        case Kind::Direct: return "direct";
        case Kind::TwoWay: return "twoway";
        case Kind::Lru: return "lru";
    }
    return "direct";
}

const char* Cache::name() const {
    switch (kind_) {
        case Kind::Direct: return "Direct-mapped";
        case Kind::TwoWay: return "Two-way set-associative";
        case Kind::Lru: return "Fully associative LRU";
    }
    return "Cache";
}

void Cache::fill(Line& line, int base, int tag) {
    line.valid = true;
    line.tag = tag;
    for (int i = 0; i < 4; ++i) line.bytes[i] = static_cast<uint8_t>(base + i);
}

void Cache::touch_lru(int way) {
    int old = age_[way];
    for (int i = 0; i < 4; ++i) {
        if (i == way) age_[i] = 0;
        else if (age_[i] < old) age_[i] += 1;
    }
}

int Cache::pick_lru() const {
    for (int i = 0; i < 4; ++i) {
        if (!fully_[i].valid) return i;
    }
    int best = 0;
    int oldest = 0;
    for (int i = 0; i < 4; ++i) {
        if (age_[i] >= oldest) {
            oldest = age_[i];
            best = i;
        }
    }
    return best;
}

void Cache::remember(const Event& event) {
    stats_.accesses += 1;
    stats_.cycles += event.cycles;
    if (event.hit) {
        stats_.hits += 1;
    } else {
        stats_.misses += 1;
        if (event.cold) stats_.cold += 1;
        else stats_.replacements += 1;
    }
    history_.push_back(event.address);
    log_.push_back(event);
    if (static_cast<int>(log_.size()) > kLogLimit) log_.erase(log_.begin());
}

void Cache::reset() {
    stats_ = {};
    log_.clear();
    history_.clear();
    seen_.fill(false);
    last_slot_ = -1;
    last_offset_ = -1;

    for (auto& line : direct_) line = {};
    for (auto& set : sets_) {
        for (auto& line : set) line = {};
    }
    lru_bit_.fill(0);
    for (auto& line : fully_) line = {};
    for (int i = 0; i < 4; ++i) age_[i] = i;
}

Event Cache::access(int address) {
    address &= 0xff;
    const int block = address >> 2;
    const int base = block << 2;
    const int offset = address & 3;
    const bool cold = !seen_[block];
    seen_[block] = true;

    Event event;
    event.address = address;
    event.offset = offset;
    event.cold = cold;

    if (kind_ == Kind::Direct) {
        const int index = (address >> 2) & 3;
        const int tag = address >> 4;
        event.tag = tag;
        event.index = index;
        Line& line = direct_[index];
        event.hit = line.valid && line.tag == tag;
        if (!event.hit) fill(line, base, tag);
        event.data = line.bytes[offset];
        event.place = "line " + std::to_string(index);
        last_slot_ = index;
    } else if (kind_ == Kind::TwoWay) {
        const int index = (address >> 2) & 1;
        const int tag = address >> 3;
        event.tag = tag;
        event.index = index;
        auto& ways = sets_[index];
        int way = -1;
        if (ways[0].valid && ways[0].tag == tag) way = 0;
        else if (ways[1].valid && ways[1].tag == tag) way = 1;
        event.hit = way >= 0;
        if (!event.hit) {
            if (!ways[0].valid) way = 0;
            else if (!ways[1].valid) way = 1;
            else way = lru_bit_[index];
            fill(ways[way], base, tag);
        }
        lru_bit_[index] = way ^ 1;
        event.way = way;
        event.data = ways[way].bytes[offset];
        event.place = "set " + std::to_string(index) + " way " + std::to_string(way);
        last_slot_ = index * 2 + way;
    } else {
        const int tag = address >> 2;
        event.tag = tag;
        event.index = -1;
        int way = -1;
        for (int i = 0; i < 4; ++i) {
            if (fully_[i].valid && fully_[i].tag == tag) {
                way = i;
                break;
            }
        }
        event.hit = way >= 0;
        if (!event.hit) {
            way = pick_lru();
            fill(fully_[way], base, tag);
        }
        touch_lru(way);
        event.way = way;
        event.data = fully_[way].bytes[offset];
        event.place = "line " + std::to_string(way);
        last_slot_ = way;
    }

    event.cycles = event.hit ? kHitCycles : kMissCycles;
    last_offset_ = offset;
    remember(event);
    return event;
}

std::vector<Slot> Cache::slots() const {
    std::vector<Slot> out;

    auto push = [&](const std::string& name, const Line& line, int slot, const std::string& mark) {
        Slot view;
        view.name = name;
        view.valid = line.valid;
        view.tag = line.tag;
        view.bytes = line.bytes;
        view.base = line.valid ? line.bytes[0] : 0;
        view.mark = mark;
        view.last = slot == last_slot_;
        view.last_offset = view.last ? last_offset_ : -1;
        out.push_back(view);
    };

    if (kind_ == Kind::Direct) {
        for (int i = 0; i < 4; ++i) push("Line " + std::to_string(i), direct_[i], i, "");
        return out;
    }

    if (kind_ == Kind::TwoWay) {
        for (int set = 0; set < 2; ++set) {
            const bool both = sets_[set][0].valid && sets_[set][1].valid;
            for (int way = 0; way < 2; ++way) {
                std::string mark;
                if (!sets_[set][way].valid && (way == 0 || sets_[set][0].valid)) mark = "fills next";
                else if (both && way == lru_bit_[set]) mark = "next victim";
                push("Set " + std::to_string(set) + "  way " + std::to_string(way),
                     sets_[set][way], set * 2 + way, mark);
            }
        }
        return out;
    }

    const int victim = pick_lru();
    const bool full = fully_[0].valid && fully_[1].valid && fully_[2].valid && fully_[3].valid;
    for (int i = 0; i < 4; ++i) {
        std::string mark;
        if (!fully_[i].valid && i == victim) mark = "fills next";
        else if (fully_[i].valid && full && i == victim) mark = "next victim";
        else if (fully_[i].valid && age_[i] == 0) mark = "most recent";
        push("Line " + std::to_string(i), fully_[i], i, mark);
    }
    return out;
}

void Cache::write_json(std::ostream& out) const {
    const auto lines = slots();
    out << "{\"id\":";
    json_string(out, id());
    out << ",\"name\":";
    json_string(out, name());
    out << ",\"stats\":{\"accesses\":" << stats_.accesses
        << ",\"hits\":" << stats_.hits
        << ",\"misses\":" << stats_.misses
        << ",\"cold\":" << stats_.cold
        << ",\"replacements\":" << stats_.replacements
        << ",\"cycles\":" << stats_.cycles << "}";

    out << ",\"slots\":[";
    for (size_t i = 0; i < lines.size(); ++i) {
        const Slot& slot = lines[i];
        if (i) out << ',';
        out << "{\"name\":";
        json_string(out, slot.name);
        out << ",\"valid\":" << (slot.valid ? "true" : "false")
            << ",\"tag\":" << slot.tag
            << ",\"base\":" << slot.base
            << ",\"mark\":";
        json_string(out, slot.mark);
        out << ",\"last\":" << (slot.last ? "true" : "false")
            << ",\"last_offset\":" << slot.last_offset
            << ",\"bytes\":[" << int(slot.bytes[0]) << ',' << int(slot.bytes[1]) << ','
            << int(slot.bytes[2]) << ',' << int(slot.bytes[3]) << "]}";
    }

    out << "],\"log\":[";
    for (size_t i = 0; i < log_.size(); ++i) {
        const Event& event = log_[i];
        if (i) out << ',';
        out << "{\"address\":" << event.address
            << ",\"hit\":" << (event.hit ? "true" : "false")
            << ",\"data\":" << event.data
            << ",\"tag\":" << event.tag
            << ",\"index\":" << event.index
            << ",\"offset\":" << event.offset
            << ",\"way\":" << event.way
            << ",\"cycles\":" << event.cycles
            << ",\"cold\":" << (event.cold ? "true" : "false")
            << ",\"place\":";
        json_string(out, event.place);
        out << '}';
    }
    out << "]}";
}

bool same_history(const std::array<Cache, 3>& caches) {
    return caches[0].history() == caches[1].history() && caches[1].history() == caches[2].history();
}

std::string state_json(const std::array<Cache, 3>& caches) {
    std::ostringstream out;
    out << "{\"same\":" << (same_history(caches) ? "true" : "false") << ",\"caches\":[";
    for (size_t i = 0; i < caches.size(); ++i) {
        if (i) out << ',';
        caches[i].write_json(out);
    }
    out << "]}";
    return out.str();
}
