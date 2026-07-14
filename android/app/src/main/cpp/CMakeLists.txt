cmake_minimum_required(VERSION 3.18.1)
project("llama_android")

set(CMAKE_CXX_STANDARD 17)

# Build llama.cpp library
add_subdirectory(llama.cpp)

# Wrapper shared library
add_library(llama_wrapper SHARED
    llama_wrapper.cpp
)

find_library(log-lib log)

target_link_libraries(llama_wrapper
    llama
    ggml
    ${log-lib}
)
