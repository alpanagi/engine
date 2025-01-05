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

std::pair<VkDevice, VkQueue>
vlk::create_device(const VkPhysicalDevice physical_device,
                   const uint32_t queue_family_index) {
  VkDevice device;

  const float queue_priorities = 1;

  VkDeviceQueueCreateInfo vk_device_queue_create_info{
      .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      .queueFamilyIndex = queue_family_index,
      .queueCount = 1,
      .pQueuePriorities = &queue_priorities,
  };

  const char *extension_names = "VK_KHR_swapchain";

  VkDeviceCreateInfo vk_device_create_info{
      .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
      .queueCreateInfoCount = 1,
      .pQueueCreateInfos = &vk_device_queue_create_info,
      .enabledExtensionCount = 1,
      .ppEnabledExtensionNames = &extension_names,
  };

  if (auto error = vkCreateDevice(physical_device, &vk_device_create_info,
                                  nullptr, &device);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }

  VkQueue queue;
  vkGetDeviceQueue(device, 0, 0, &queue);

  return {device, queue};
}

VkSurfaceCapabilitiesKHR
vlk::get_surface_capabilities(const VkPhysicalDevice physical_device,
                              const VkSurfaceKHR surface) {
  VkSurfaceCapabilitiesKHR surface_capabilities;

  if (auto error = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
          physical_device, surface, &surface_capabilities);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }

  return surface_capabilities;
}

VkSwapchainKHR
vlk::create_swapchain(const VkDevice device, const VkSurfaceKHR surface,
                      const VkSurfaceCapabilitiesKHR surface_capabilities) {
  VkSwapchainKHR swapchain;

  VkSwapchainCreateInfoKHR vk_swapchain_create_info{
      .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
      .surface = surface,
      .minImageCount = surface_capabilities.minImageCount,
      .imageFormat = VK_FORMAT_B8G8R8A8_UNORM,
      .imageColorSpace = VK_COLORSPACE_SRGB_NONLINEAR_KHR,
      .imageExtent = surface_capabilities.currentExtent,
      .imageArrayLayers = 1,
      .imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
      .preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
      .compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
      .presentMode = VK_PRESENT_MODE_FIFO_KHR,
  };

  if (auto error = vkCreateSwapchainKHR(device, &vk_swapchain_create_info,
                                        nullptr, &swapchain);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }

  return swapchain;
}

std::vector<VkImage> vlk::get_swapchain_images(const VkDevice device,
                                               const VkSwapchainKHR swapchain) {
  uint32_t count;
  if (auto error = vkGetSwapchainImagesKHR(device, swapchain, &count, nullptr);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }

  std::vector<VkImage> images(count);
  if (auto error =
          vkGetSwapchainImagesKHR(device, swapchain, &count, images.data());
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }

  return images;
}

uint32_t vlk::get_next_swapchain_image(const VkDevice device,
                                       const VkSwapchainKHR swapchain,
                                       const VkSemaphore swapchain_semaphore) {
  uint32_t image_index;
  if (auto error = vkAcquireNextImageKHR(
          device, swapchain, 0, swapchain_semaphore, nullptr, &image_index);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }

  return image_index;
}

void vlk::submit_queue(const VkQueue queue,
                       const VkCommandBuffer command_buffer) {
  VkSubmitInfo vk_submit_info{
      .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
      .commandBufferCount = 1,
      .pCommandBuffers = &command_buffer,
  };

  if (auto error = vkQueueSubmit(queue, 1, &vk_submit_info, nullptr);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }
}

void vlk::present(const VkQueue queue, const VkSwapchainKHR swapchain,
                  const VkSemaphore swapchain_semaphore,
                  const uint32_t image_index) {
  VkPresentInfoKHR vk_present_info{
      .sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
      .waitSemaphoreCount = 1,
      .pWaitSemaphores = &swapchain_semaphore,
      .swapchainCount = 1,
      .pSwapchains = &swapchain,
      .pImageIndices = &image_index,
  };

  if (auto error = vkQueuePresentKHR(queue, &vk_present_info);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }
}

VkFramebuffer
vlk::create_framebuffer(const VkDevice device, const VkRenderPass render_pass,
                        const VkSurfaceCapabilitiesKHR surface_capabilities) {
  VkFramebuffer framebuffer;

  VkFramebufferCreateInfo vk_framebuffer_create_info{
      .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
      .renderPass = render_pass,
      .attachmentCount = 0,
      .pAttachments = nullptr,
      .width = surface_capabilities.currentExtent.width,
      .height = surface_capabilities.currentExtent.height,
      .layers = 1,
  };

  if (auto error = vkCreateFramebuffer(device, &vk_framebuffer_create_info,
                                       nullptr, &framebuffer);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }

  return framebuffer;
}

VkRenderPass vlk::render_pass::create(const VkDevice device) {
  VkRenderPass render_pass;

  VkSubpassDescription vk_subpass_description{
      .pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
      .inputAttachmentCount = 0,
      .pInputAttachments = nullptr,
      .colorAttachmentCount = 0,
      .pColorAttachments = nullptr,
  };

  VkRenderPassCreateInfo vk_render_pass_create_info{
      .sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
      .attachmentCount = 0,
      .pAttachments = nullptr,
      .subpassCount = 1,
      .pSubpasses = &vk_subpass_description,
  };

  if (auto error = vkCreateRenderPass(device, &vk_render_pass_create_info,
                                      nullptr, &render_pass);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }

  return render_pass;
}

void vlk::render_pass::begin(const VkCommandBuffer command_buffer,
                             const VkRenderPass render_pass,
                             const VkFramebuffer frame_buffer) {
  VkClearValue clear_value = {
      .color = {0.0, 0.0, 0.0, 1.0},
  };

  VkRenderPassBeginInfo vk_render_pass_begin_info{
      .sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
      .renderPass = render_pass,
      .framebuffer = frame_buffer,
      .clearValueCount = 1,
      .pClearValues = &clear_value,
  };

  vkCmdBeginRenderPass(command_buffer, &vk_render_pass_begin_info,
                       VK_SUBPASS_CONTENTS_INLINE);
}

VkCommandPool vlk::create_command_pool(const VkDevice device,
                                       const uint32_t queue_family_index) {
  VkCommandPool command_pool;

  VkCommandPoolCreateInfo vk_command_pool_create_info{
      .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
      .queueFamilyIndex = queue_family_index,
  };

  if (auto error = vkCreateCommandPool(device, &vk_command_pool_create_info,
                                       nullptr, &command_pool);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }

  return command_pool;
}

VkCommandBuffer vlk::command_buffer::create(const VkDevice device,
                                            const VkCommandPool command_pool) {
  VkCommandBuffer command_buffer;

  VkCommandBufferAllocateInfo vk_command_buffer_allocate_info{
      .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
      .commandPool = command_pool,
      .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
      .commandBufferCount = 1,
  };

  if (auto error = vkAllocateCommandBuffers(
          device, &vk_command_buffer_allocate_info, &command_buffer);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }

  return command_buffer;
}

void vlk::command_buffer::begin(const VkCommandBuffer command_buffer) {
  VkCommandBufferBeginInfo vk_command_buffer_begin_info{
      .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
  };

  if (auto error =
          vkBeginCommandBuffer(command_buffer, &vk_command_buffer_begin_info);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }
}

void vlk::command_buffer::end(const VkCommandBuffer command_buffer) {
  if (auto error = vkEndCommandBuffer(command_buffer); error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }
}

VkSemaphore vlk::semaphore::create(const VkDevice device) {
  VkSemaphore semaphore;

  VkSemaphoreCreateInfo vk_semaphore_create_info{
      .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
  };

  if (auto error = vkCreateSemaphore(device, &vk_semaphore_create_info, nullptr,
                                     &semaphore);
      error != VK_SUCCESS) {
    panik::crash(panik::component::vulkan, string_VkResult(error));
  }
  return semaphore;
}
