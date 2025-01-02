#ifndef _VLK_H_
#define _VLK_H_

#include "vulkan/vulkan.h"
#include <string>
#include <vector>

namespace vlk {
VkInstance create_instance(const std::vector<std::string> &extensions_names);
VkPhysicalDevice get_physical_device(const VkInstance);
std::pair<VkDevice, VkQueue> create_device(const VkPhysicalDevice,
                                           const uint32_t queue_family_index);
VkCommandPool create_command_pool(const VkDevice,
                                  const uint32_t queue_family_index);

VkCommandBuffer create_command_buffer(const VkDevice, const VkCommandPool);
} // namespace vlk

#endif
