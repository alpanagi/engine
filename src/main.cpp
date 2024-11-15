#include "load.h"
#include "vlk.h"
#include <iostream>

int main() {
  auto meshes = load::meshes();
  auto objects = load::objects(meshes);

  for (auto object : objects) {
    std::cout << "name: " << object.name << std::endl;
    std::cout << "mesh: " << object.mesh->name << std::endl;
  }

  auto instance = vlk::create_instance();
  auto physical_device = vlk::get_physical_device(instance);
  auto device = vlk::create_device(physical_device);
}
