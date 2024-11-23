#ifndef _GRAPHICS_GRAPHICS_H
#define _GRAPHICS_GRAPHICS_H

#include <vector>
#include <vulkan/vulkan_core.h>

class Graphics {
public:
  Graphics(const VkInstance instance, const VkSurfaceKHR surface);
  ~Graphics();

  void render();
  void recreate_rendering();
  void destroy_rendering();

  bool should_recreate_swapchain = false;

private:
  VkInstance instance;
  VkSurfaceKHR surface;
  VkPhysicalDevice physical_device;
  VkDevice device;
  VkQueue queue;
  VkCommandPool command_pool;
  VkCommandBuffer command_buffer;

  VkSurfaceCapabilitiesKHR surface_capabilities;

  VkSwapchainKHR swapchain = VK_NULL_HANDLE;
  std::vector<VkImage> swapchain_images;
  std::vector<VkImageView> swapchain_image_views;
  std::vector<VkFramebuffer> framebuffers;
  VkRenderPass renderpass;

  VkSemaphore acquire_image_semaphore;
  VkSemaphore render_finished_semaphore;
  VkFence in_flight_fence;
};

#endif
