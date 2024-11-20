#include "graphics.h"
#include "vlk.h"
#include <vulkan/vulkan_core.h>

Graphics::Graphics(VkInstance instance_, VkSurfaceKHR surface_) {
  const uint32_t queue_family_index = 0;

  instance = instance_;
  surface = surface_;

  physical_device = vlk::physical_device(instance);
  std::tie(device, queue) =
      vlk::device_and_queue(physical_device, queue_family_index);
  command_pool = vlk::command_pool(device, queue_family_index);

  surface_capabilities = vlk::surface_capabilities(physical_device, surface);
  swapchain = vlk::swapchain(device, surface, surface_capabilities);

  render();
}

Graphics::~Graphics() {
  vkDestroyCommandPool(device, command_pool, nullptr);
  vkDestroyDevice(device, nullptr);
  vkDestroySurfaceKHR(instance, surface, nullptr);
  vkDestroyInstance(instance, nullptr);
}

void Graphics::recreate_swapchain() {
  vlk::destroy_swapchain(device, swapchain);
  swapchain = vlk::swapchain(device, surface, surface_capabilities);
}

void Graphics::render() const {
  VkCommandBuffer command_buffer = vlk::command_buffer(device, command_pool);
  VkRenderPass renderpass = vlk::renderpass(device);
  VkFence fence = vlk::fence(device);
  VkImage image = vlk::next_swapchain_image(device, swapchain, fence);
  VkImageView image_view = vlk::image_view(device, image);
  VkFramebuffer framebuffer =
      vlk::framebuffer(device, swapchain, renderpass, image_view);

  vlk::begin_drawing(device, command_buffer, surface, surface_capabilities);
  vlk::begin_render_pass(surface_capabilities, command_buffer, renderpass,
                         framebuffer);
  vlk::end_render_pass(command_buffer);
  vlk::end_drawing(command_buffer);
}
