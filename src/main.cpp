#include "graphics/graphics.h"
#include "graphics/vlk.h"
#include "graphics/window.h"

int main(int argc, char *argv[]) {
  Window window("Engine");
  VkInstance instance = vlk::instance(window.vulkan_instance_extensions());
  VkSurfaceKHR surface = window.surface(instance);
  Graphics graphics(instance, surface);
  window.start_event_loop(graphics);
}

// auto meshes = load::meshes();
// auto objects = load::objects(meshes);

// for (auto object : objects) {
//   std::cout << "name: " << object.name << std::endl;
//   std::cout << "mesh: " << object.mesh->name << std::endl;
// }
