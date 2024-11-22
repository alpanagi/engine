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
  command_buffer = vlk::command_buffer(device, command_pool);

  surface_capabilities = vlk::surface_capabilities(physical_device, surface);
  recreate_rendering();

  acquire_image_semaphore = vlk::semaphore(device);
  present_semaphore = vlk::semaphore(device);
  in_flight_fence = vlk::fence(device);

  render();
}

Graphics::~Graphics() {
  vkDestroyFence(device, in_flight_fence, nullptr);
  vkDestroySemaphore(device, acquire_image_semaphore, nullptr);
  vkDestroySemaphore(device, present_semaphore, nullptr);

  destroy_rendering();

  vlk::reset_command_buffer(command_buffer);

  vkDestroyCommandPool(device, command_pool, nullptr);
  vkDestroyDevice(device, nullptr);
  vkDestroySurfaceKHR(instance, surface, nullptr);
  vkDestroyInstance(instance, nullptr);
}

void Graphics::recreate_rendering() {
  vkQueueWaitIdle(queue);
  destroy_rendering();

  swapchain = vlk::swapchain(device, surface, surface_capabilities);
  swapchain_images = vlk::swapchain_images(device, swapchain);
  for (VkImage image : swapchain_images) {
    VkImageView image_view = vlk::image_view(device, image);
    swapchain_image_views.push_back(image_view);
  }

  renderpass = vlk::renderpass(device, swapchain_image_views.size());
  framebuffer =
      vlk::framebuffer(device, swapchain, renderpass, swapchain_image_views);
}

void Graphics::destroy_rendering() {
  if (swapchain != VK_NULL_HANDLE) {
    vkDestroyFramebuffer(device, framebuffer, nullptr);
    vkDestroyRenderPass(device, renderpass, nullptr);
    for (VkImageView swapchain_image_view : swapchain_image_views) {
      vkDestroyImageView(device, swapchain_image_view, nullptr);
    }
    swapchain_image_views = {};
    vkDestroySwapchainKHR(device, swapchain, nullptr);
  }
}

void Graphics::render() const {
  vlk::await_fence(device, in_flight_fence);
  vlk::reset_fence(device, in_flight_fence);

  uint32_t swapchain_image_index = vlk::next_swapchain_image_index(
      device, swapchain, acquire_image_semaphore);

  vlk::begin_drawing(device, command_buffer);
  vlk::begin_render_pass(surface_capabilities, command_buffer, renderpass,
                         framebuffer, swapchain_image_views.size());
  vlk::end_render_pass(command_buffer);
  vlk::end_drawing(command_buffer);
  vlk::submit_command_buffer(queue, command_buffer, in_flight_fence,
                             acquire_image_semaphore);

  vlk::present(queue, swapchain, swapchain_image_index);
}
