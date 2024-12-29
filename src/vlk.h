#ifndef _VLK_H_
#define _VLK_H_

#include "vulkan/vulkan.h"
#include <string>
#include <vector>

namespace vlk {
VkInstance create_instance(const std::vector<std::string> &extensions_names);
}

#endif
