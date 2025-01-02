#include "vlk.h"
#include "panik.h"
#include "vulkan/vk_enum_string_helper.h"
#include <vulkan/vulkan_core.h>

VkInstance
vlk::create_instance(const std::vector<std::string> &extension_names) {
  VkInstance instance;

  const char *layer_names = "VK_LAYER_KHRONOS_validation";

  std::vector<const char *> c_str_extension_names(extension_names.size());
  for (int i = 0; i < extension_names.size(); i++) {
    c_str_extension_names[i] = extension_names[i].c_str();
  }

  VkInstanceCreateInfo vk_instance_create_info{
      .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
      .enabledLayerCount = 1,
      .ppEnabledLayerNames = &layer_names,
      .enabledExtensionCount = static_cast<uint32_t>(extension_names.size()),
      .ppEnabledExtensionNames = c_str_extension_names.data(),
  };

  if (auto error =
          vkCreateInstance(&vk_instance_create_info, nullptr, &instance);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }

  return instance;
}

VkPhysicalDevice vlk::get_physical_device(const VkInstance instance) {
  VkPhysicalDevice physical_device;

  uint32_t count = 1;
  if (auto error =
          vkEnumeratePhysicalDevices(instance, &count, &physical_device);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }

  return physical_device;
}

std::pair<VkDevice, VkQueue>
vlk::create_device(const VkPhysicalDevice physical_device,
                   const uint32_t queue_family_index) {
  VkDevice device;

  const float queue_priorities = 1;

  VkDeviceQueueCreateInfo vk_device_queue_create_info{
      .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      .queueFamilyIndex = queue_family_index,
      .queueCount = 1,
      .pQueuePriorities = &queue_priorities,
  };

  VkDeviceCreateInfo vk_device_create_info{
      .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
      .queueCreateInfoCount = 1,
      .pQueueCreateInfos = &vk_device_queue_create_info,
  };

  if (auto error = vkCreateDevice(physical_device, &vk_device_create_info,
                                  nullptr, &device);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }

  VkQueue queue;
  vkGetDeviceQueue(device, 0, 0, &queue);

  return {device, queue};
}

VkCommandPool vlk::create_command_pool(const VkDevice device,
                                       const uint32_t queue_family_index) {
  VkCommandPool command_pool;

  VkCommandPoolCreateInfo vk_command_pool_create_info{
      .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
      .queueFamilyIndex = queue_family_index,
  };

  if (auto error = vkCreateCommandPool(device, &vk_command_pool_create_info,
                                       nullptr, &command_pool);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }

  return command_pool;
}

VkCommandBuffer vlk::create_command_buffer(const VkDevice device,
                                           const VkCommandPool command_pool) {
  VkCommandBuffer command_buffer;

  VkCommandBufferAllocateInfo vk_command_buffer_allocate_info{
      .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
      .commandPool = command_pool,
      .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
      .commandBufferCount = 1,
  };

  vkAllocateCommandBuffers(device, &vk_command_buffer_allocate_info,
                           &command_buffer);

  return command_buffer;
}
