#include "graphics.h"
#include "sdlk.h"
#include "vlk.h"
#include <SDL3/SDL_main.h>
#include <print>

int main() {
  sdlk::initialize();
  auto window = sdlk::create_window("engine");

  std::vector<std::string> extension_names =
      sdlk::get_required_vulkan_extensions();
  auto instance = vlk::create_instance(extension_names);

  auto surface = sdlk::create_surface(window, instance);
  Graphics graphics(instance, surface);
  graphics.render();
}
