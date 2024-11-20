#ifndef _GRAPHICS_GRAPHICS_H
#define _GRAPHICS_GRAPHICS_H

#include <vulkan/vulkan_core.h>

class Graphics {
public:
  Graphics(const VkInstance instance, const VkSurfaceKHR surface);
  ~Graphics();

  void render() const;
  void recreate_swapchain();

private:
  VkInstance instance;
  VkSurfaceKHR surface;
  VkPhysicalDevice physical_device;
  VkDevice device;
  VkQueue queue;
  VkCommandPool command_pool;
  VkSurfaceCapabilitiesKHR surface_capabilities;
  VkSwapchainKHR swapchain;
};

#endif
