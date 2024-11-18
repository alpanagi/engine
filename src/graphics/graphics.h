#ifndef _GRAPHICS_GRAPHICS_H
#define _GRAPHICS_GRAPHICS_H

#include "window.h"
#include <vulkan/vulkan_core.h>

class Graphics {
public:
  Graphics(const Window);
  ~Graphics();

  void render() const;

private:
  VkInstance instance;
  VkSurfaceKHR surface;
  VkPhysicalDevice physical_device;
  VkDevice device;
  VkQueue queue;
  VkCommandPool command_pool;
};

#endif
