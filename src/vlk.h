#ifndef _VLK_H_
#define _VLK_H_

#include <vulkan/vulkan.h>

namespace vlk {
VkInstance create_instance();
VkPhysicalDevice get_physical_device(const VkInstance);
VkDevice create_device(const VkPhysicalDevice);
} // namespace vlk

#endif
