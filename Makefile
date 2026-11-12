CXX = g++
CXXFLAGS = -std=c++17 -O2 -Wall -Wextra -pedantic
SRCS = src/cpp/main.cpp src/cpp/cache.cpp

.PHONY: all check run clean

all: cache_bench

cache_bench: $(SRCS) src/cpp/cache.hpp
	$(CXX) $(CXXFLAGS) -o cache_bench $(SRCS)

check: cache_bench
	./cache_bench check

run: cache_bench
	./cache_bench

clean:
	rm -f cache_bench
