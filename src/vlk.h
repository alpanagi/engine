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

namespace swapchain {
VkSwapchainKHR create(const VkDevice, const VkSurfaceKHR,
                      const VkSurfaceCapabilitiesKHR);
std::vector<VkImage> get_images(const VkDevice, const VkSwapchainKHR);
uint32_t get_next_image(const VkDevice, const VkSwapchainKHR,
                        const VkSemaphore swapchain_semaphore);
} // namespace swapchain

VkCommandPool create_command_pool(const VkDevice,
                                  const uint32_t queue_family_index);
void submit_queue(const VkQueue, const VkCommandBuffer);
void present(const VkQueue, const VkSwapchainKHR,
             const VkSemaphore swapchain_semaphore, const uint32_t image_index);

VkFramebuffer create_framebuffer(const VkDevice, const VkRenderPass,
                                 const VkSurfaceCapabilitiesKHR);
VkShaderModule create_shader_module(const VkDevice,
                                    const std::string &filename);
VkPipelineLayout create_pipeline_layout(const VkDevice);
VkPipeline create_pipeline(const VkDevice, const VkRenderPass,
                           const VkSurfaceCapabilitiesKHR);

namespace command_buffer {
VkCommandBuffer create(const VkDevice, const VkCommandPool);
void begin(const VkCommandBuffer);
void end(const VkCommandBuffer);
} // namespace command_buffer

namespace semaphore {
VkSemaphore create(const VkDevice);
}

namespace render_pass {
VkRenderPass create(const VkDevice);
void begin(const VkCommandBuffer, const VkRenderPass, const VkFramebuffer,
           const VkSurfaceCapabilitiesKHR);
void end(const VkCommandBuffer);
} // namespace render_pass
} // namespace vlk

#endif
