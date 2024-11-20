#ifndef _WINDOW_H_
#define _WINDOW_H_

#include "graphics.h"
#include <SDL3/SDL.h>
#include <string>
#include <vector>
#include <vulkan/vulkan_core.h>

class Window {
public:
  Window(const std::string title);
  ~Window();

  VkSurfaceKHR surface(const VkInstance) const;
  std::vector<const char *> vulkan_instance_extensions() const;
  void start_event_loop(Graphics graphics) const;

private:
  SDL_Window *window;
};

#endif
