#ifndef _GRAPHICS_H_
#define _GRAPHICS_H_

#include "vulkan/vulkan.h"

class Graphics {
private:
  VkInstance instance;
  VkPhysicalDevice physical_device;
  VkDevice device;
  VkQueue queue;

  VkCommandPool command_pool;
  VkCommandBuffer command_buffer;

public:
  Graphics(const VkInstance);
  void render();
};

#endif
