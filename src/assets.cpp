#include "assets.h"
#include "panik.h"
#include <fstream>
#include <vector>

std::vector<char> assets::shaders::load(const std::string &filename) {
  std::ifstream shader_file(filename, std::ios::binary);
  if (!shader_file.is_open()) {
    panik::crash(panik::component::assets,
                 std::format("Failed to open file: \"{}\"", filename));
  }

  std::vector<char> buffer(std::istreambuf_iterator<char>{shader_file},
                           std::istreambuf_iterator<char>{});
  return buffer;
}
