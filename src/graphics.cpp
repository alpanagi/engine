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
  swapchain = vlk::swapchain::create(device, surface, surface_capabilities);
  swapchain_images = vlk::swapchain::get_images(device, swapchain);
  swapchain_image_views =
      vlk::swapchain::get_image_views(device, swapchain_images);
  render_pass = vlk::render_pass::create(device);

  framebuffers = std::vector<VkFramebuffer>(swapchain_image_views.size());
  for (int i = 0; i < swapchain_image_views.size(); i++) {
    framebuffers[i] =
        vlk::create_framebuffer(device, render_pass, surface_capabilities);
  }

  pipeline = vlk::create_pipeline(device, render_pass, surface_capabilities);

  command_pool = vlk::create_command_pool(device, queue_family_index);
  command_buffer = vlk::command_buffer::create(device, command_pool);

  swapchain_semaphore = vlk::semaphore::create(device);
}

void Graphics::render() {
  auto image_index =
      vlk::swapchain::get_next_image(device, swapchain, swapchain_semaphore);
  vlk::command_buffer::begin(command_buffer);
  vlk::render_pass::begin(command_buffer, render_pass,
                          framebuffers[image_index], surface_capabilities);
  vlk::render_pass::end(command_buffer);
  vlk::command_buffer::end(command_buffer);
  vlk::submit_queue(queue, command_buffer);
  vlk::present(queue, swapchain, swapchain_semaphore, image_index);
}
