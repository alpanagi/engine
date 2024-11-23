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
  renderpass = vlk::renderpass(device);

  recreate_rendering();

  acquire_image_semaphore = vlk::semaphore(device);
  render_finished_semaphore = vlk::semaphore(device);
  in_flight_fence = vlk::fence(device);

  render();
}

Graphics::~Graphics() {
  vkDeviceWaitIdle(device);
  destroy_rendering();

  vkDestroyRenderPass(device, renderpass, nullptr);

  vkDestroyFence(device, in_flight_fence, nullptr);
  vkDestroySemaphore(device, acquire_image_semaphore, nullptr);
  vkDestroySemaphore(device, render_finished_semaphore, nullptr);

  vkDestroyCommandPool(device, command_pool, nullptr);
  vkDestroyDevice(device, nullptr);
  vkDestroySurfaceKHR(instance, surface, nullptr);
  vkDestroyInstance(instance, nullptr);
}

void Graphics::recreate_rendering() {
  vkDeviceWaitIdle(device);

  if (swapchain != VK_NULL_HANDLE) {
    destroy_rendering();
  }

  surface_capabilities = vlk::surface_capabilities(physical_device, surface);
  swapchain = vlk::swapchain(device, surface, surface_capabilities);
  swapchain_images = vlk::swapchain_images(device, swapchain);
  for (VkImage image : swapchain_images) {
    VkImageView image_view = vlk::image_view(device, image);
    swapchain_image_views.push_back(image_view);
  }

  for (int i = 0; i < swapchain_image_views.size(); i++) {
    framebuffers.push_back(vlk::framebuffer(device, swapchain, renderpass,
                                            swapchain_image_views[i],
                                            surface_capabilities));
  }
}

void Graphics::destroy_rendering() {
  for (VkFramebuffer framebuffer : framebuffers) {
    vkDestroyFramebuffer(device, framebuffer, nullptr);
  }

  for (VkImageView swapchain_image_view : swapchain_image_views) {
    vkDestroyImageView(device, swapchain_image_view, nullptr);
  }

  swapchain_image_views = {};
  framebuffers = {};
  vkDestroySwapchainKHR(device, swapchain, nullptr);
}

void Graphics::render() {
  vlk::await_fence(device, in_flight_fence);

  auto [swapchain_image_index, error] = vlk::next_swapchain_image_index(
      device, swapchain, acquire_image_semaphore);

  if (error != VK_SUCCESS) {
    if (error == VK_ERROR_OUT_OF_DATE_KHR) {
      should_recreate_swapchain = true;
    } else {
      vlk::panic(error);
    }
  }

  vlk::reset_fence(device, in_flight_fence);

  vlk::begin_drawing(device, command_buffer);
  vlk::begin_render_pass(surface_capabilities, command_buffer, renderpass,
                         framebuffers[swapchain_image_index],
                         swapchain_image_views.size());
  vlk::end_render_pass(command_buffer);
  vlk::end_drawing(command_buffer);
  vlk::submit_command_buffer(queue, command_buffer, in_flight_fence,
                             acquire_image_semaphore,
                             render_finished_semaphore);

  error = vlk::present(queue, swapchain, swapchain_image_index,
                       render_finished_semaphore);
  if (error != VK_SUCCESS) {
    if (error == VK_ERROR_OUT_OF_DATE_KHR) {
      should_recreate_swapchain = true;
    } else {
      vlk::panic(error);
    }
  }
}
