#ifndef _GRAPHICS_H_
#define _GRAPHICS_H_

#include "vulkan/vulkan.h"
#include <vector>
#include <vulkan/vulkan_core.h>

class Graphics {
private:
  VkInstance instance;
  VkPhysicalDevice physical_device;
  VkSurfaceKHR surface;
  VkDevice device;
  VkQueue queue;

  VkSurfaceCapabilitiesKHR surface_capabilities;
  VkSwapchainKHR swapchain;
  std::vector<VkImage> swapchain_images;

  VkCommandPool command_pool;
  VkCommandBuffer command_buffer;

  VkSemaphore swapchain_semaphore;

public:
  Graphics(const VkInstance, const VkSurfaceKHR);
  void render();
};

#endif
