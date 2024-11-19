#include "graphics.h"
#include "vlk.h"
#include <iostream>
#include <vulkan/vulkan_core.h>

Graphics::Graphics(Window window) {
  const uint32_t queue_family_index = 0;

  instance = vlk::create_instance(window.vulkan_instance_extensions());
  surface = window.surface(instance);

  physical_device = vlk::get_physical_device(instance);
  std::tie(device, queue) =
      vlk::create_device_and_queue(physical_device, queue_family_index);
  command_pool = vlk::create_command_pool(device, queue_family_index);
  render();
}

Graphics::~Graphics() {
  vkDestroyCommandPool(device, command_pool, nullptr);
  vkDestroyDevice(device, nullptr);
  vkDestroySurfaceKHR(instance, surface, nullptr);
  vkDestroyInstance(instance, nullptr);
}

void Graphics::render() const {
  VkCommandBuffer command_buffer =
      vlk::get_command_buffer(device, command_pool);

  vlk::begin_drawing(command_buffer);
  vlk::end_drawing(queue, command_buffer);
}
