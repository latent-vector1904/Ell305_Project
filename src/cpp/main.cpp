#include "cache.hpp"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <algorithm>
#include <cctype>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <sstream>
#include <string>

namespace {

constexpr int kDefaultPort = 8090;

std::array<Cache, 3> caches{Cache(Kind::Direct), Cache(Kind::TwoWay), Cache(Kind::Lru)};

Cache* find_cache(const std::string& id) {
    for (auto& cache : caches) {
        if (id == cache.id()) return &cache;
    }
    return nullptr;
}

std::string shape_of(const std::vector<Event>& log) {
    std::string shape;
    for (const auto& event : log) shape.push_back(event.hit ? 'H' : 'M');
    return shape;
}

bool expect(const char* label, Kind kind, const std::vector<int>& addresses, const std::string& want) {
    Cache cache(kind);
    for (int address : addresses) cache.access(address);
    const std::string got = shape_of(cache.log());
    const bool ok = got == want;
    std::cout << (ok ? "ok  " : "FAIL ") << label << "  " << got;
    if (!ok) std::cout << "  expected " << want;
    std::cout << "\n";
    return ok;
}

int run_checks() {
    const std::vector<int> conflict = {0x00, 0x10, 0x00, 0x10};
    const std::vector<int> replacement = {0x00, 0x00, 0x10, 0x00};
    const std::vector<int> three = {0x00, 0x10, 0x00, 0x20, 0x00, 0x10};
    const std::vector<int> capacity = {0x00, 0x04, 0x08, 0x0C, 0x00, 0x04, 0x08, 0x0C};
    const std::vector<int> spatial = {0x00, 0x01, 0x02, 0x03};
    const std::vector<int> temporal = {0x00, 0x00, 0x00, 0x00};
    const std::vector<int> victim = {0x00, 0x04, 0x08, 0x0C, 0x04, 0x08, 0x0C, 0x10};

    int failed = 0;
    auto check = [&](const char* label, Kind kind, const std::vector<int>& addresses, const std::string& want) {
        if (!expect(label, kind, addresses, want)) failed += 1;
    };

    check("conflict direct", Kind::Direct, conflict, "MMMM");
    check("conflict two-way", Kind::TwoWay, conflict, "MMHH");
    check("conflict lru", Kind::Lru, conflict, "MMHH");
    check("replacement direct", Kind::Direct, replacement, "MHMM");
    check("replacement two-way", Kind::TwoWay, replacement, "MHMH");
    check("replacement lru", Kind::Lru, replacement, "MHMH");
    check("three-block direct", Kind::Direct, three, "MMMMMM");
    check("three-block two-way", Kind::TwoWay, three, "MMHMHM");
    check("three-block lru", Kind::Lru, three, "MMHMHH");
    check("capacity direct", Kind::Direct, capacity, "MMMMHHHH");
    check("capacity two-way", Kind::TwoWay, capacity, "MMMMHHHH");
    check("capacity lru", Kind::Lru, capacity, "MMMMHHHH");
    check("spatial direct", Kind::Direct, spatial, "MHHH");
    check("spatial two-way", Kind::TwoWay, spatial, "MHHH");
    check("spatial lru", Kind::Lru, spatial, "MHHH");
    check("temporal direct", Kind::Direct, temporal, "MHHH");
    check("temporal lru", Kind::Lru, temporal, "MHHH");
    check("victim lru", Kind::Lru, victim, "MMMMHHHM");

    Cache bytes(Kind::Direct);
    Event first = bytes.access(0x02);
    Event second = bytes.access(0x03);
    if (first.hit || first.data != 0x02 || !second.hit || second.data != 0x03) {
        std::cout << "FAIL byte read  data " << first.data << " then " << second.data << "\n";
        failed += 1;
    } else {
        std::cout << "ok  byte equals address\n";
    }

    Cache aged(Kind::Lru);
    for (int address : victim) aged.access(address);
    const auto slots = aged.slots();
    const bool victim_ok = slots.size() == 4 && slots[0].valid && slots[0].base == 0x10 &&
                           slots[1].base == 0x04 && slots[2].base == 0x08 && slots[3].base == 0x0C;
    if (!victim_ok) {
        std::cout << "FAIL victim replaced line 0\n";
        failed += 1;
    } else {
        std::cout << "ok  untouched line is the victim\n";
    }

    if (failed) {
        std::cout << failed << " check(s) failed\n";
        return 1;
    }
    std::cout << "all checks passed\n";
    return 0;
}

std::string json_error(const std::string& message) {
    std::ostringstream out;
    out << "{\"error\":\"";
    for (char ch : message) {
        if (ch == '"' || ch == '\\') out << '\\';
        out << ch;
    }
    out << "\"}";
    return out.str();
}

std::string field(const std::string& body, const std::string& key) {
    const std::string needle = "\"" + key + "\"";
    const auto at = body.find(needle);
    if (at == std::string::npos) return {};
    auto colon = body.find(':', at + needle.size());
    if (colon == std::string::npos) return {};
    auto first = body.find('"', colon + 1);
    if (first == std::string::npos) return {};
    auto last = body.find('"', first + 1);
    if (last == std::string::npos) return {};
    return body.substr(first + 1, last - first - 1);
}

bool flag(const std::string& body, const std::string& key) {
    const std::string needle = "\"" + key + "\"";
    const auto at = body.find(needle);
    if (at == std::string::npos) return false;
    auto colon = body.find(':', at + needle.size());
    if (colon == std::string::npos) return false;
    return body.find("true", colon) != std::string::npos &&
           (body.find("false", colon) == std::string::npos || body.find("true", colon) < body.find("false", colon));
}

std::vector<int> addresses_of(const std::string& body, std::string& error) {
    const auto at = body.find("\"addresses\"");
    if (at == std::string::npos) {
        error = "Missing addresses.";
        return {};
    }
    auto open = body.find('[', at);
    auto close = body.find(']', open == std::string::npos ? at : open);
    if (open == std::string::npos || close == std::string::npos) {
        error = "Addresses must be a list of numbers.";
        return {};
    }
    std::vector<int> addresses;
    int value = 0;
    bool in_number = false;
    bool negative = false;
    for (size_t i = open + 1; i < close; ++i) {
        const char ch = body[i];
        if (ch == '-' && !in_number) {
            negative = true;
            continue;
        }
        if (std::isdigit(static_cast<unsigned char>(ch))) {
            in_number = true;
            value = value * 10 + (ch - '0');
            continue;
        }
        if (in_number) {
            if (negative || value > 255) {
                error = "Addresses must be from 0 to 255.";
                return {};
            }
            addresses.push_back(value);
            value = 0;
            in_number = false;
            negative = false;
        }
    }
    if (in_number) {
        if (negative || value > 255) {
            error = "Addresses must be from 0 to 255.";
            return {};
        }
        addresses.push_back(value);
    }
    if (addresses.size() > 512) {
        error = "At most 512 addresses at once.";
        return {};
    }
    return addresses;
}

std::string apply_request(const std::string& body) {
    const std::string target = field(body, "target");
    if (target.empty()) return json_error("Choose a cache.");

    std::vector<Cache*> chosen;
    if (target == "all") {
        for (auto& cache : caches) chosen.push_back(&cache);
    } else {
        Cache* cache = find_cache(target);
        if (!cache) return json_error("Unknown cache.");
        chosen.push_back(cache);
    }

    if (flag(body, "clear")) {
        for (Cache* cache : chosen) cache->reset();
    }

    if (body.find("\"addresses\"") == std::string::npos) return state_json(caches);

    std::string error;
    const auto addresses = addresses_of(body, error);
    if (!error.empty()) return json_error(error);
    for (int address : addresses) {
        for (Cache* cache : chosen) cache->access(address);
    }
    return state_json(caches);
}

std::string read_file(const std::string& path) {
    FILE* file = std::fopen(path.c_str(), "rb");
    if (!file) return {};
    std::string data;
    char buf[4096];
    size_t n = 0;
    while ((n = std::fread(buf, 1, sizeof buf, file)) > 0) data.append(buf, n);
    std::fclose(file);
    return data;
}

void send_all(int fd, const std::string& bytes) {
    size_t sent = 0;
    while (sent < bytes.size()) {
        const ssize_t n = ::send(fd, bytes.data() + sent, bytes.size() - sent, MSG_NOSIGNAL);
        if (n <= 0) return;
        sent += static_cast<size_t>(n);
    }
}

void respond(int fd, int status, const std::string& type, const std::string& body) {
    std::ostringstream out;
    out << "HTTP/1.1 " << status << (status == 200 ? " OK" : " Error") << "\r\n"
        << "Content-Type: " << type << "\r\n"
        << "Content-Length: " << body.size() << "\r\n"
        << "Connection: close\r\n"
        << "Cache-Control: no-store\r\n\r\n"
        << body;
    send_all(fd, out.str());
}

std::string request_of(int fd) {
    std::string data;
    char buf[2048];
    while (data.find("\r\n\r\n") == std::string::npos) {
        const ssize_t n = ::recv(fd, buf, sizeof buf, 0);
        if (n <= 0) return data;
        data.append(buf, n);
        if (data.size() > 200000) return data;
    }
    const auto header_end = data.find("\r\n\r\n");
    const auto length_at = data.find("Content-Length:");
    int length = 0;
    if (length_at != std::string::npos && length_at < header_end) {
        length = std::atoi(data.c_str() + length_at + 15);
    }
    const size_t need = header_end + 4 + static_cast<size_t>(std::max(length, 0));
    while (data.size() < need) {
        const ssize_t n = ::recv(fd, buf, sizeof buf, 0);
        if (n <= 0) break;
        data.append(buf, n);
    }
    return data;
}

void handle(int fd, const std::string& html_path) {
    const std::string request = request_of(fd);
    if (request.empty()) return;
    const auto line_end = request.find("\r\n");
    const std::string start = request.substr(0, line_end == std::string::npos ? request.size() : line_end);
    const auto body_at = request.find("\r\n\r\n");
    const std::string body = body_at == std::string::npos ? std::string() : request.substr(body_at + 4);

    if (start.rfind("GET / ", 0) == 0 || start.rfind("GET /index.html ", 0) == 0) {
        const std::string page = read_file(html_path);
        if (page.empty()) {
            respond(fd, 500, "text/plain", "Could not read " + html_path + "\n");
        } else {
            respond(fd, 200, "text/html; charset=utf-8", page);
        }
        return;
    }
    if (start.rfind("GET /api/state ", 0) == 0) {
        respond(fd, 200, "application/json", state_json(caches));
        return;
    }
    if (start.rfind("POST /api/access ", 0) == 0 || start.rfind("POST /api/reset ", 0) == 0) {
        const std::string result = apply_request(body);
        const bool bad = result.find("\"error\"") == 0;
        respond(fd, bad ? 400 : 200, "application/json", result);
        return;
    }
    if (start.rfind("GET /favicon.ico ", 0) == 0) {
        respond(fd, 204, "text/plain", "");
        return;
    }
    respond(fd, 404, "text/plain", "Not found\n");
}

int serve(int port, const std::string& html_path) {
    std::signal(SIGPIPE, SIG_IGN);
    const int server = ::socket(AF_INET, SOCK_STREAM, 0);
    if (server < 0) {
        std::perror("socket");
        return 1;
    }
    int yes = 1;
    ::setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof yes);

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(static_cast<uint16_t>(port));
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (::bind(server, reinterpret_cast<sockaddr*>(&addr), sizeof addr) < 0) {
        std::perror("bind");
        ::close(server);
        return 1;
    }
    if (::listen(server, 16) < 0) {
        std::perror("listen");
        ::close(server);
        return 1;
    }

    std::cout << "Cache bench is running.\n"
              << "Open http://127.0.0.1:" << port << "\n"
              << "The page is " << html_path << " and every access is computed by this program.\n";
    std::cout.flush();

    while (true) {
        const int client = ::accept(server, nullptr, nullptr);
        if (client < 0) continue;
        handle(client, html_path);
        ::close(client);
    }
}

}  // namespace

int main(int argc, char** argv) {
    if (argc >= 2 && std::strcmp(argv[1], "check") == 0) return run_checks();

    int port = kDefaultPort;
    std::string html_path = "web/index.html";
    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "serve") continue;
        if (arg.rfind("--page=", 0) == 0) html_path = arg.substr(7);
        else port = std::atoi(arg.c_str());
    }
    if (port <= 0 || port > 65535) port = kDefaultPort;
    return serve(port, html_path);
}
