#include "vlk.h"
#include <iostream>
#include <vulkan/vk_enum_string_helper.h>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_core.h>

void vlk::panic(const VkResult error) {
  std::cout << "[VULKAN] " << string_VkResult(error) << std::endl;
  exit(1);
}

VkInstance vlk::core::instance(std::vector<const char *> extensions) {
  VkInstance instance;

  const char *layer_names[] = {"VK_LAYER_KHRONOS_validation",
                               "VK_LAYER_LUNARG_api_dump"};

  VkInstanceCreateInfo instance_create_info{
      .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
      .enabledLayerCount = 1,
      .ppEnabledLayerNames = &layer_names[0],
      .enabledExtensionCount = static_cast<uint32_t>(extensions.size()),
      .ppEnabledExtensionNames = extensions.data(),
  };

  if (auto result = vkCreateInstance(&instance_create_info, nullptr, &instance);
      result != VK_SUCCESS) {
    vlk::panic(result);
  }

  return instance;
}

VkPhysicalDevice vlk::core::physical_device(const VkInstance instance) {
  VkPhysicalDevice physical_device;

  uint32_t device_count = 1;

  if (auto error =
          vkEnumeratePhysicalDevices(instance, &device_count, &physical_device);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }

  return physical_device;
}

VkSurfaceCapabilitiesKHR
vlk::core::surface_capabilities(const VkPhysicalDevice physical_device,
                                const VkSurfaceKHR surface) {
  VkSurfaceCapabilitiesKHR surface_capabilities;

  if (auto error = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
          physical_device, surface, &surface_capabilities);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }

  return surface_capabilities;
}

std::pair<VkDevice, VkQueue>
vlk::core::device_and_queue(const VkPhysicalDevice physical_device,
                            const uint32_t queue_family_index) {
  VkDevice device;
  VkQueue queue;

  const char *extension_names = VK_KHR_SWAPCHAIN_EXTENSION_NAME;
  const float queue_priority = 1.0;

  VkDeviceQueueCreateInfo device_queue_create_info{
      .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      .queueFamilyIndex = queue_family_index,
      .queueCount = 1,
      .pQueuePriorities = &queue_priority,
  };

  VkDeviceCreateInfo device_create_info{
      .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
      .queueCreateInfoCount = 1,
      .pQueueCreateInfos = &device_queue_create_info,
      .enabledExtensionCount = 1,
      .ppEnabledExtensionNames = &extension_names,
  };

  if (auto error = vkCreateDevice(physical_device, &device_create_info, nullptr,
                                  &device);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }

  vkGetDeviceQueue(device, queue_family_index, 0, &queue);

  return {
      device,
      queue,
  };
}

VkCommandPool vlk::core::command_pool(const VkDevice device,
                                      const uint32_t queue_family_index) {
  VkCommandPool command_pool;

  VkCommandPoolCreateInfo command_pool_create_info{
      .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
      .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
      .queueFamilyIndex = queue_family_index,
  };

  if (auto error = vkCreateCommandPool(device, &command_pool_create_info,
                                       nullptr, &command_pool);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }

  return command_pool;
}

VkCommandBuffer vlk::command_buffer::create(const VkDevice device,
                                            const VkCommandPool command_pool) {
  VkCommandBuffer command_buffer;

  VkCommandBufferAllocateInfo command_buffer_allocate_info{
      .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
      .commandPool = command_pool,
      .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
      .commandBufferCount = 1,
  };

  if (auto error = vkAllocateCommandBuffers(
          device, &command_buffer_allocate_info, &command_buffer);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }

  return command_buffer;
}

void vlk::command_buffer::reset(const VkCommandBuffer command_buffer) {
  if (auto error = vkResetCommandBuffer(command_buffer, 0);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }
}

void vlk::command_buffer::submit(const VkQueue queue,
                                 const VkCommandBuffer command_buffer,
                                 const VkFence in_flight_fence,
                                 const VkSemaphore acquire_image_semaphore,
                                 const VkSemaphore render_finished_semaphore) {
  uint32_t dst_stages[] = {VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT};
  VkSubmitInfo submit_info{
      .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
      .waitSemaphoreCount = 1,
      .pWaitSemaphores = &acquire_image_semaphore,
      .pWaitDstStageMask = dst_stages,
      .commandBufferCount = 1,
      .pCommandBuffers = &command_buffer,
      .signalSemaphoreCount = 1,
      .pSignalSemaphores = &render_finished_semaphore,
  };

  if (auto error = vkQueueSubmit(queue, 1, &submit_info, in_flight_fence);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }
}

VkFence vlk::fence::create(const VkDevice device) {
  VkFence fence;

  VkFenceCreateInfo fence_create_info{
      .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
      .flags = VK_FENCE_CREATE_SIGNALED_BIT,
  };

  if (auto error = vkCreateFence(device, &fence_create_info, nullptr, &fence);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }

  return fence;
}

void vlk::fence::await(const VkDevice device, const VkFence fence) {
  if (auto error = vkWaitForFences(device, 1, &fence, true, UINT64_MAX);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }
}

void vlk::fence::reset(const VkDevice device, const VkFence fence) {
  if (auto error = vkResetFences(device, 1, &fence); error != VK_SUCCESS) {
    vlk::panic(error);
  }
}

VkSemaphore vlk::semaphore::create(const VkDevice device) {
  VkSemaphore semaphore;

  VkSemaphoreCreateInfo semaphore_create_info{
      .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
  };

  if (auto error = vkCreateSemaphore(device, &semaphore_create_info, nullptr,
                                     &semaphore);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }

  return semaphore;
}

VkRenderPass vlk::graphics::renderpass(const VkDevice device) {
  VkRenderPass render_pass;

  VkAttachmentDescription attachment_description(VkAttachmentDescription{
      .format = VK_FORMAT_B8G8R8A8_UNORM,
      .samples = VK_SAMPLE_COUNT_1_BIT,
      .loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
      .storeOp = VK_ATTACHMENT_STORE_OP_STORE,
      .stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      .stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
      .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
      .finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
  });

  VkSubpassDescription subpass_description{
      .pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
      .inputAttachmentCount = 0,
      .pInputAttachments = nullptr,
      .colorAttachmentCount = 0,
      .pColorAttachments = nullptr,
  };

  VkRenderPassCreateInfo render_pass_create_info{
      .sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
      .attachmentCount = 1,
      .pAttachments = &attachment_description,
      .subpassCount = 1,
      .pSubpasses = &subpass_description,
  };

  if (auto error = vkCreateRenderPass(device, &render_pass_create_info, nullptr,
                                      &render_pass);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }

  return render_pass;
}

VkSwapchainKHR
vlk::graphics::swapchain(const VkDevice device, const VkSurfaceKHR surface,
                         const VkSurfaceCapabilitiesKHR surface_capabilities) {
  VkSwapchainKHR swapchain;

  VkSwapchainCreateInfoKHR swapchain_create_info{
      .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
      .surface = surface,
      .minImageCount = surface_capabilities.minImageCount,
      .imageFormat = VK_FORMAT_B8G8R8A8_UNORM,
      .imageColorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
      .imageExtent = surface_capabilities.currentExtent,
      .imageArrayLayers = 1,
      .imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
      .imageSharingMode = VK_SHARING_MODE_EXCLUSIVE,
      .preTransform = surface_capabilities.currentTransform,
      .compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
      .presentMode = VK_PRESENT_MODE_FIFO_KHR,
  };

  if (auto error = vkCreateSwapchainKHR(device, &swapchain_create_info, nullptr,
                                        &swapchain);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }

  return swapchain;
}

std::vector<VkImage>
vlk::graphics::swapchain_images(const VkDevice device,
                                const VkSwapchainKHR swapchain) {
  uint32_t image_count;
  if (auto error =
          vkGetSwapchainImagesKHR(device, swapchain, &image_count, nullptr);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }

  VkImage swapchain_images[image_count];
  if (auto error = vkGetSwapchainImagesKHR(device, swapchain, &image_count,
                                           &swapchain_images[0]);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }

  std::vector<VkImage> swapchain_image_vector;
  for (VkImage image : swapchain_images) {
    swapchain_image_vector.push_back(image);
  }

  return swapchain_image_vector;
}

VkImageView vlk::graphics::image_view(const VkDevice device,
                                      const VkImage image) {
  VkImageView image_view;

  VkComponentMapping component_mapping{
      .r = VK_COMPONENT_SWIZZLE_IDENTITY,
      .g = VK_COMPONENT_SWIZZLE_IDENTITY,
      .b = VK_COMPONENT_SWIZZLE_IDENTITY,
      .a = VK_COMPONENT_SWIZZLE_IDENTITY,
  };

  VkImageSubresourceRange image_subresource_range{
      .aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
      .baseMipLevel = 0,
      .levelCount = 1,
      .baseArrayLayer = 0,
      .layerCount = 1,
  };

  VkImageViewCreateInfo image_view_create_info{
      .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
      .image = image,
      .viewType = VK_IMAGE_VIEW_TYPE_2D,
      .format = VK_FORMAT_B8G8R8A8_UNORM,
      .components = component_mapping,
      .subresourceRange = image_subresource_range,
  };

  if (auto error = vkCreateImageView(device, &image_view_create_info, nullptr,
                                     &image_view);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }

  return image_view;
}

VkFramebuffer vlk::graphics::framebuffer(
    const VkDevice device, const VkSwapchainKHR swapchain,
    const VkRenderPass render_pass, const VkImageView image_view,
    const VkSurfaceCapabilitiesKHR surface_capabilities) {
  VkFramebuffer framebuffer;
  VkFramebufferCreateInfo framebuffer_create_info{
      .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
      .renderPass = render_pass,
      .attachmentCount = 1,
      .pAttachments = &image_view,
      .width = surface_capabilities.currentExtent.width,
      .height = surface_capabilities.currentExtent.height,
      .layers = 1,
  };
  if (auto error = vkCreateFramebuffer(device, &framebuffer_create_info,
                                       nullptr, &framebuffer);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }

  return framebuffer;
}

std::pair<uint32_t, VkResult>
vlk::graphics::next_swapchain_image_index(const VkDevice device,
                                          const VkSwapchainKHR swapchain,
                                          const VkSemaphore semaphore) {
  uint32_t image_index;

  auto error = vkAcquireNextImageKHR(device, swapchain, UINT64_MAX, semaphore,
                                     VK_NULL_HANDLE, &image_index);

  return {image_index, error};
}

void vlk::drawing::begin(const VkDevice device,
                         const VkCommandBuffer command_buffer) {
  VkCommandBufferBeginInfo command_buffer_begin_info{
      .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
  };
  if (auto error =
          vkBeginCommandBuffer(command_buffer, &command_buffer_begin_info);
      error != VK_SUCCESS) {
    vlk::panic(error);
  }
}

void vlk::drawing::begin_render_pass(
    const VkSurfaceCapabilitiesKHR surface_capabilities,
    const VkCommandBuffer command_buffer, const VkRenderPass renderpass,
    const VkFramebuffer framebuffer,
    const uint32_t swapchain_image_view_count) {
  VkClearValue clear_color_value{
      .color = {0.0f, 0.0f, 0.0f, 1.0f},
  };

  VkRect2D rect{
      .offset = {0, 0},
      .extent = surface_capabilities.currentExtent,
  };

  VkRenderPassBeginInfo render_pass_begin_info{
      .sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
      .renderPass = renderpass,
      .framebuffer = framebuffer,
      .renderArea = rect,
      .clearValueCount = 1,
      .pClearValues = &clear_color_value,
  };

  vkCmdBeginRenderPass(command_buffer, &render_pass_begin_info,
                       VK_SUBPASS_CONTENTS_INLINE);
}

void vlk::drawing::end_render_pass(VkCommandBuffer command_buffer) {
  vkCmdEndRenderPass(command_buffer);
}

void vlk::drawing::end(const VkCommandBuffer command_buffer) {
  if (auto error = vkEndCommandBuffer(command_buffer); error != VK_SUCCESS) {
    vlk::panic(error);
  }
}

VkResult vlk::drawing::present(const VkQueue queue,
                               const VkSwapchainKHR swapchain,
                               const uint32_t swapchain_image_index,
                               const VkSemaphore render_finished_semaphore) {
  VkPresentInfoKHR present_info{
      .sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
      .waitSemaphoreCount = 1,
      .pWaitSemaphores = &render_finished_semaphore,
      .swapchainCount = 1,
      .pSwapchains = &swapchain,
      .pImageIndices = &swapchain_image_index,
  };

  return vkQueuePresentKHR(queue, &present_info);
}
