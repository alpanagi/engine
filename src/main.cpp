#include "load.h"
#include <iostream>

int main() {
  auto meshes = load::meshes();
  auto objects = load::objects(meshes);

  for (auto object : objects) {
    std::cout << "name: " << object.name << std::endl;
    std::cout << "mesh: " << object.mesh.name << std::endl;
  }
}
