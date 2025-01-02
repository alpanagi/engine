#include "graphics.h"
#include "vlk.h"
#include <vulkan/vulkan_core.h>

Graphics::Graphics(const VkInstance instance) {
  physical_device = vlk::get_physical_device(instance);

  uint32_t queue_family_index = 0;

  auto [device_, queue_] =
      vlk::create_device(physical_device, queue_family_index);
  device = device_;
  queue = queue_;

  command_pool = vlk::create_command_pool(device, queue_family_index);
  command_buffer = vlk::command_buffer::create(device, command_pool);
}

void Graphics::render() {
  vlk::command_buffer::begin(command_buffer);
  vlk::command_buffer::end(command_buffer);
  vlk::submit_queue(queue, command_buffer);
}
