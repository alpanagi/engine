#include "graphics/graphics.h"
#include "graphics/window.h"

int main(int argc, char *argv[]) {
  Window window("Engine");
  Graphics graphics(window);
  window.start_event_loop();
}

// auto meshes = load::meshes();
// auto objects = load::objects(meshes);

// for (auto object : objects) {
//   std::cout << "name: " << object.name << std::endl;
//   std::cout << "mesh: " << object.mesh->name << std::endl;
// }
