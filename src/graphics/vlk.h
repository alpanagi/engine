#ifndef _VLK_H_
#define _VLK_H_

#include <vector>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_core.h>

namespace vlk {
void panic(const VkResult);
VkInstance instance(std::vector<const char *> extensions);
VkPhysicalDevice physical_device(const VkInstance);
VkSurfaceCapabilitiesKHR surface_capabilities(const VkPhysicalDevice,
                                              const VkSurfaceKHR);
std::pair<VkDevice, VkQueue>
device_and_queue(const VkPhysicalDevice, const uint32_t queue_family_index);
VkCommandPool command_pool(const VkDevice, const uint32_t queue_family_index);
VkCommandBuffer command_buffer(const VkDevice, const VkCommandPool);
VkSwapchainKHR swapchain(const VkDevice, const VkSurfaceKHR,
                         const VkSurfaceCapabilitiesKHR);
VkRenderPass renderpass(const VkDevice);
VkFence fence(const VkDevice);
VkImage next_swapchain_image(const VkDevice, const VkSwapchainKHR,
                             const VkFence);
VkImageView image_view(const VkDevice, const VkImage);
VkFramebuffer framebuffer(const VkDevice, const VkSwapchainKHR,
                          const VkRenderPass, const VkImageView);
void begin_drawing(const VkDevice, const VkCommandBuffer, const VkSurfaceKHR,
                   const VkSurfaceCapabilitiesKHR);
void begin_render_pass(const VkSurfaceCapabilitiesKHR, const VkCommandBuffer,
                       const VkRenderPass, const VkFramebuffer);
void end_render_pass(VkCommandBuffer);
void end_drawing(const VkCommandBuffer);
void submit_command_buffer(const VkQueue queue,
                           const VkCommandBuffer command_buffer);
void destroy_swapchain(const VkDevice, const VkSwapchainKHR);
} // namespace vlk

#endif
