cmake_minimum_required(VERSION 3.31)
project(engine)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(SDL3 REQUIRED)
find_package(Vulkan REQUIRED)

add_executable(engine)
target_link_libraries(engine
  ${SDL3_LIBRARIES}
  ${Vulkan_LIBRARIES}
)
target_sources(engine PRIVATE
  src/main.cpp
  src/sdlk.cpp
  src/vlk.cpp
  src/panik.cpp
)
