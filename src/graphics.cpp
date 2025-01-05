#include "graphics.h"
#include "vlk.h"
#include <vulkan/vulkan_core.h>

Graphics::Graphics(const VkInstance instance_, const VkSurfaceKHR surface_) {
  instance = instance_;
  surface = surface_;

  physical_device = vlk::get_physical_device(instance);

  uint32_t queue_family_index = 0;

  auto [device_, queue_] =
      vlk::create_device(physical_device, queue_family_index);
  device = device_;
  queue = queue_;

  surface_capabilities =
      vlk::get_surface_capabilities(physical_device, surface);
  swapchain = vlk::create_swapchain(device, surface, surface_capabilities);
  swapchain_images = vlk::get_swapchain_images(device, swapchain);

  command_pool = vlk::create_command_pool(device, queue_family_index);
  command_buffer = vlk::command_buffer::create(device, command_pool);
}

void Graphics::render() {
  auto image_index = vlk::get_next_swapchain_image(device, swapchain);
  vlk::command_buffer::begin(command_buffer);
  vlk::command_buffer::end(command_buffer);
  vlk::submit_queue(queue, command_buffer);
  vlk::present(queue, swapchain, image_index);
}
