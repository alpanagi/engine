#include "vlk.h"
#include <vulkan/vulkan_core.h>

VkInstance vlk::create_instance() {
  VkInstance instance;

  const char *layer_names = "VK_LAYER_KHRONOS_validation";

  VkInstanceCreateInfo vk_instance_create_info{
      .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
      .enabledLayerCount = 1,
      .ppEnabledLayerNames = &layer_names,
  };
  vkCreateInstance(&vk_instance_create_info, nullptr, &instance);

  return instance;
}
