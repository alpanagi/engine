cmake_minimum_required(VERSION 3.30)
project(engine)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(engine)
target_sources(engine PRIVATE
  src/main.cpp
  src/load.cpp
  src/error.cpp
  src/object.cpp
  src/mesh.cpp
)
