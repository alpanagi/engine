#ifndef _PANIK_H_
#define _PANIK_H_

#include <string>

namespace panik {
enum class component {
  assets,
  sdl,
  vulkan,
};
void crash(component, const std::string &msg);
} // namespace panik

#endif
