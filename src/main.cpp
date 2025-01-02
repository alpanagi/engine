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
  auto physical_device = vlk::get_physical_device(instance);

  uint32_t queue_family_index;
  auto [device, queue] =
      vlk::create_device(physical_device, queue_family_index);
  auto command_pool = vlk::create_command_pool(device, queue_family_index);
  auto command_buffer = vlk::create_command_buffer(device, command_pool);
}
