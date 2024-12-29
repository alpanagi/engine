#include "panik.h"
#include <print>

void panik::crash(panik::component component, const std::string &msg) {
  std::string component_name = "UNKNOWN";
  switch (component) {
  case component::sdl:
    component_name = "SDL";
    break;
  case component::vulkan:
    component_name = "VULKAN";
    break;
  }

  std::print("[ERROR][{}] {}", component_name, msg);
  exit(1);
}
