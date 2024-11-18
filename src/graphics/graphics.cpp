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
  VkCommandBuffer command_buffer;

  VkCommandBufferAllocateInfo command_buffer_allocate_info{
      .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
      .commandPool = command_pool,
      .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
      .commandBufferCount = 1,
  };
  if (auto error = vkAllocateCommandBuffers(
          device, &command_buffer_allocate_info, &command_buffer);
      error != VK_SUCCESS) {
    std::cout << "UPDATE LOG CODE: " << error << std::endl;
  }

  VkCommandBufferBeginInfo command_buffer_begin_info{
      .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
      .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
  };
  if (auto error =
          vkBeginCommandBuffer(command_buffer, &command_buffer_begin_info);
      error != VK_SUCCESS) {
    std::cout << "UPDATE LOG CODE: " << error << std::endl;
  }
  if (auto error = vkEndCommandBuffer(command_buffer); error != VK_SUCCESS) {
    std::cout << "UPDATE LOG CODE: " << error << std::endl;
  }

  VkSubmitInfo submit_info{
      .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
      .commandBufferCount = 1,
      .pCommandBuffers = &command_buffer,
  };
  if (auto error = vkQueueSubmit(queue, 1, &submit_info, VK_NULL_HANDLE);
      error != VK_SUCCESS) {
    std::cout << "UPDATE LOG CODE: " << error << std::endl;
  }
}
