#include "vlk.h"
#include <iostream>
#include <vulkan/vk_enum_string_helper.h>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_core.h>

void vlk_panic(std::string msg) {
  std::cout << "[VULKAN] " << msg << std::endl;
  exit(1);
}

VkInstance vlk::create_instance() {
  VkInstance instance;

  const char *layer_names = "VK_LAYER_KHRONOS_validation";

  VkInstanceCreateInfo instance_create_info{
      .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
      .enabledLayerCount = 1,
      .ppEnabledLayerNames = &layer_names,
  };

  if (auto error = vkCreateInstance(&instance_create_info, nullptr, &instance);
      error != VK_SUCCESS) {
    vlk_panic(string_VkResult(error));
  }

  return instance;
}

VkPhysicalDevice vlk::get_physical_device(const VkInstance instance) {
  VkPhysicalDevice physical_device;

  uint32_t device_count = 1;
  if (auto error =
          vkEnumeratePhysicalDevices(instance, &device_count, &physical_device);
      error != VK_SUCCESS) {
    vlk_panic(string_VkResult(error));
  }

  return physical_device;
}

VkDevice vlk::create_device(const VkPhysicalDevice physical_device) {
  VkDevice device;

  const char *extension_names = "";
  const float queue_priority = 1.0;

  VkDeviceQueueCreateInfo device_queue_create_info{
      .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      .queueFamilyIndex = 0,
      .queueCount = 1,
      .pQueuePriorities = &queue_priority,
  };

  VkDeviceCreateInfo device_create_info{
      .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
      .queueCreateInfoCount = 1,
      .pQueueCreateInfos = &device_queue_create_info,
      .enabledExtensionCount = 0,
      .ppEnabledExtensionNames = nullptr,
  };

  if (auto error = vkCreateDevice(physical_device, &device_create_info, nullptr,
                                  &device);
      error != VK_SUCCESS) {
    vlk_panic(string_VkResult(error));
  }

  return device;
}
