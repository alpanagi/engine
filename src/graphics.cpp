#include "graphics.h"
#include "vlk.h"

Graphics::Graphics(const VkInstance instance) {
  physical_device = vlk::get_physical_device(instance);

  uint32_t queue_family_index = 0;

  auto [device_, queue_] =
      vlk::create_device(physical_device, queue_family_index);
  device = device_;
  queue = queue_;

  command_pool = vlk::create_command_pool(device, queue_family_index);
  command_buffer = vlk::create_command_buffer(device, command_pool);
}
