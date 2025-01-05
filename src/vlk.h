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
std::vector<VkImage> get_swapchain_images(const VkDevice, const VkSwapchainKHR);
uint32_t get_next_swapchain_image(const VkDevice device,
                                  const VkSwapchainKHR swapchain,
                                  const VkSemaphore semaphore);

VkCommandPool create_command_pool(const VkDevice,
                                  const uint32_t queue_family_index);
void submit_queue(const VkQueue, const VkCommandBuffer);
void present(const VkQueue, const VkSwapchainKHR,
             const VkSemaphore swapchain_semaphore, const uint32_t image_index);

namespace command_buffer {
VkCommandBuffer create(const VkDevice, const VkCommandPool);
void begin(const VkCommandBuffer);
void end(const VkCommandBuffer);
} // namespace command_buffer

namespace semaphore {
VkSemaphore create(const VkDevice);
}
} // namespace vlk

#endif
