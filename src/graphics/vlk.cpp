#include "vlk.h"
#include <iostream>
#include <vulkan/vk_enum_string_helper.h>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_core.h>

void vlk_panic(VkResult error) {
  std::cout << "[VULKAN] " << string_VkResult(error) << std::endl;
  exit(1);
}

VkInstance vlk::create_instance(std::vector<const char *> extensions) {
  VkInstance instance;

  const char *layer_names[] = {"VK_LAYER_KHRONOS_validation",
                               "VK_LAYER_LUNARG_api_dump"};

  VkInstanceCreateInfo instance_create_info{
      .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
      .enabledLayerCount = 1,
      .ppEnabledLayerNames = &layer_names[0],
      .enabledExtensionCount = static_cast<uint32_t>(extensions.size()),
      .ppEnabledExtensionNames = extensions.data(),
  };

  if (auto error = vkCreateInstance(&instance_create_info, nullptr, &instance);
      error != VK_SUCCESS) {
    vlk_panic(error);
  }

  return instance;
}

VkPhysicalDevice vlk::get_physical_device(const VkInstance instance) {
  VkPhysicalDevice physical_device;

  uint32_t device_count = 1;
  if (auto error =
          vkEnumeratePhysicalDevices(instance, &device_count, &physical_device);
      error != VK_SUCCESS) {
    vlk_panic(error);
  }

  return physical_device;
}

std::pair<VkDevice, VkQueue>
vlk::create_device_and_queue(const VkPhysicalDevice physical_device,
                             const uint32_t queue_family_index) {
  VkDevice device;
  VkQueue queue;

  const char *extension_names = "VK_KHR_swapchain";
  const float queue_priority = 1.0;

  VkDeviceQueueCreateInfo device_queue_create_info{
      .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      .queueFamilyIndex = queue_family_index,
      .queueCount = 1,
      .pQueuePriorities = &queue_priority,
  };

  VkDeviceCreateInfo device_create_info{
      .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
      .queueCreateInfoCount = 1,
      .pQueueCreateInfos = &device_queue_create_info,
      .enabledExtensionCount = 1,
      .ppEnabledExtensionNames = &extension_names,
  };

  if (auto error = vkCreateDevice(physical_device, &device_create_info, nullptr,
                                  &device);
      error != VK_SUCCESS) {
    vlk_panic(error);
  }

  vkGetDeviceQueue(device, queue_family_index, 0, &queue);

  return {
      device,
      queue,
  };
}

VkCommandPool vlk::create_command_pool(const VkDevice device,
                                       const uint32_t queue_family_index) {
  VkCommandPool command_pool;

  VkCommandPoolCreateInfo command_pool_create_info{
      .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
      .queueFamilyIndex = queue_family_index,
  };
  if (auto error = vkCreateCommandPool(device, &command_pool_create_info,
                                       nullptr, &command_pool);
      error != VK_SUCCESS) {
    vlk_panic(error);
  }

  return command_pool;
}
