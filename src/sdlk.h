#ifndef _SDLK_H_
#define _SDLK_H_

#include <SDL3/SDL.h>
#include <SDL3/SDL_vulkan.h>
#include <string>
#include <vector>

namespace sdlk {
void initialize();
SDL_Window *create_window(const std::string &title);
VkSurfaceKHR create_surface(SDL_Window *, const VkInstance);
std::vector<std::string> get_required_vulkan_extensions();
} // namespace sdlk

#endif
