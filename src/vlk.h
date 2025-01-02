#ifndef _VLK_H_
#define _VLK_H_

#include "vulkan/vulkan.h"
#include <string>
#include <vector>
#include <vulkan/vulkan_core.h>

namespace vlk {
VkInstance create_instance(const std::vector<std::string> &extensions_names);
VkPhysicalDevice get_physical_device(const VkInstance);
std::pair<VkDevice, VkQueue> create_device(const VkPhysicalDevice,
                                           const uint32_t queue_family_index);
VkSurfaceCapabilitiesKHR
get_surface_capabilities(const VkPhysicalDevice physical_device,
                         const VkSurfaceKHR surface);
VkSwapchainKHR create_swapchain(const VkDevice, const VkSurfaceKHR,
                                const VkSurfaceCapabilitiesKHR);

VkCommandPool create_command_pool(const VkDevice,
                                  const uint32_t queue_family_index);
void submit_queue(const VkQueue, const VkCommandBuffer);
void present(const VkQueue, const VkSwapchainKHR);

namespace command_buffer {
VkCommandBuffer create(const VkDevice, const VkCommandPool);
void begin(const VkCommandBuffer);
void end(const VkCommandBuffer);
} // namespace command_buffer
} // namespace vlk

#endif
