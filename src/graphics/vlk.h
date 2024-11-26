#ifndef _VLK_H_
#define _VLK_H_

#include <vector>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_core.h>

namespace vlk {
void panic(const VkResult);
} // namespace vlk

namespace vlk::core {
VkInstance instance(std::vector<const char *> extensions);
VkPhysicalDevice physical_device(const VkInstance);
VkSurfaceCapabilitiesKHR surface_capabilities(const VkPhysicalDevice,
                                              const VkSurfaceKHR);
std::pair<VkDevice, VkQueue>
device_and_queue(const VkPhysicalDevice, const uint32_t queue_family_index);
VkCommandPool command_pool(const VkDevice, const uint32_t queue_family_index);
} // namespace vlk::core

namespace vlk::command_buffer {
VkCommandBuffer create(const VkDevice, const VkCommandPool);
void reset(const VkCommandBuffer);
void submit(const VkQueue, const VkCommandBuffer, const VkFence in_flight_fence,
            const VkSemaphore acquire_image_semaphore,
            const VkSemaphore render_finished_semaphore);
} // namespace vlk::command_buffer

namespace vlk::fence {
VkFence create(const VkDevice);
void await(const VkDevice, const VkFence);
void reset(const VkDevice, const VkFence);
} // namespace vlk::fence

namespace vlk::semaphore {
VkSemaphore create(const VkDevice);
} // namespace vlk::semaphore

namespace vlk::graphics {
VkRenderPass renderpass(const VkDevice);
VkSwapchainKHR swapchain(const VkDevice, const VkSurfaceKHR,
                         const VkSurfaceCapabilitiesKHR);
std::vector<VkImage> swapchain_images(const VkDevice, const VkSwapchainKHR);
VkImageView image_view(const VkDevice, const VkImage);
VkFramebuffer framebuffer(const VkDevice, const VkSwapchainKHR,
                          const VkRenderPass, const VkImageView,
                          const VkSurfaceCapabilitiesKHR surface_capabilities);
std::pair<uint32_t, VkResult> next_swapchain_image_index(const VkDevice,
                                                         const VkSwapchainKHR,
                                                         const VkSemaphore);
} // namespace vlk::graphics

namespace vlk::drawing {
void begin(const VkDevice, const VkCommandBuffer);
void begin_render_pass(const VkSurfaceCapabilitiesKHR, const VkCommandBuffer,
                       const VkRenderPass, const VkFramebuffer,
                       const uint32_t swapchain_image_view_count);
void end_render_pass(VkCommandBuffer);
void end(const VkCommandBuffer);
VkResult present(const VkQueue, const VkSwapchainKHR,
                 const uint32_t swapchain_image_index,
                 const VkSemaphore render_finished_semaphore);
} // namespace vlk::drawing

#endif
