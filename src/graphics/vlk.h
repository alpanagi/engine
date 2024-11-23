#ifndef _VLK_H_
#define _VLK_H_

#include <vector>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_core.h>

namespace vlk {
void panic(const VkResult);

// Setup
VkInstance instance(std::vector<const char *> extensions);
VkPhysicalDevice physical_device(const VkInstance);
VkSurfaceCapabilitiesKHR surface_capabilities(const VkPhysicalDevice,
                                              const VkSurfaceKHR);
std::pair<VkDevice, VkQueue>
device_and_queue(const VkPhysicalDevice, const uint32_t queue_family_index);
VkCommandPool command_pool(const VkDevice, const uint32_t queue_family_index);
VkCommandBuffer command_buffer(const VkDevice, const VkCommandPool);
void reset_command_buffer(const VkCommandBuffer command_buffer);

VkRenderPass renderpass(const VkDevice);
VkSwapchainKHR swapchain(const VkDevice, const VkSurfaceKHR,
                         const VkSurfaceCapabilitiesKHR);
std::vector<VkImage> swapchain_images(const VkDevice, const VkSwapchainKHR);
std::pair<uint32_t, VkResult> next_swapchain_image_index(const VkDevice,
                                                         const VkSwapchainKHR,
                                                         const VkSemaphore);
VkImageView image_view(const VkDevice, const VkImage);
VkFramebuffer framebuffer(const VkDevice, const VkSwapchainKHR,
                          const VkRenderPass, const VkImageView,
                          const VkSurfaceCapabilitiesKHR surface_capabilities);

// Frame
void begin_drawing(const VkDevice, const VkCommandBuffer);
void begin_render_pass(const VkSurfaceCapabilitiesKHR, const VkCommandBuffer,
                       const VkRenderPass, const VkFramebuffer,
                       const uint32_t swapchain_image_view_count);
void end_render_pass(VkCommandBuffer);
void end_drawing(const VkCommandBuffer);
void submit_command_buffer(const VkQueue, const VkCommandBuffer,
                           const VkFence in_flight_fence,
                           const VkSemaphore acquire_image_semaphore,
                           const VkSemaphore render_finished_semaphore);
VkResult present(const VkQueue, const VkSwapchainKHR,
                 const uint32_t swapchain_image_index,
                 const VkSemaphore render_finished_semaphore);

// Synchronization
VkFence fence(const VkDevice);
void await_fence(const VkDevice, const VkFence);
void reset_fence(const VkDevice, const VkFence);
VkSemaphore semaphore(const VkDevice);
} // namespace vlk

#endif
