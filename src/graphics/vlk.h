#ifndef _VLK_H_
#define _VLK_H_

#include <vector>
#include <vulkan/vulkan.h>

namespace vlk {
VkInstance create_instance(std::vector<const char *> extensions);
VkPhysicalDevice get_physical_device(const VkInstance);
std::pair<VkDevice, VkQueue>
create_device_and_queue(const VkPhysicalDevice,
                        const uint32_t queue_family_index);
VkCommandPool create_command_pool(const VkDevice device,
                                  const uint32_t queue_family_index);
VkCommandBuffer get_command_buffer(const VkDevice, const VkCommandPool);
void begin_drawing(const VkCommandBuffer);
void end_drawing(const VkQueue queue, const VkCommandBuffer command_buffer);
} // namespace vlk

#endif
