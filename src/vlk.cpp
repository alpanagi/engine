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
