cmake_minimum_required(VERSION 3.30)
project(engine)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Vulkan REQUIRED)
find_package(SDL3 REQUIRED)

add_executable(engine)
target_link_libraries(engine
  ${Vulkan_LIBRARIES}
)
target_link_libraries(engine
  ${SDL3_LIBRARIES}
)
target_sources(engine PRIVATE
  src/main.cpp
  src/load.cpp
  src/error.cpp
  src/object.cpp
  src/mesh.cpp
  src/graphics/vlk.cpp
  src/graphics/window.cpp
  src/graphics/graphics.cpp
)
