#include "window.h"
#include <SDL3/SDL_events.h>
#include <SDL3/SDL_stdinc.h>
#include <SDL3/SDL_vulkan.h>
#include <iostream>

void sdl_panic() {
  std::cout << "[SDL] " << SDL_GetError() << std::endl;
  exit(1);
}

SDL_Window *create_window(const std::string title) {
  SDL_Window *window = SDL_CreateWindow(
      title.c_str(), 800, 600, SDL_WINDOW_VULKAN | SDL_WINDOW_RESIZABLE);
  if (window == nullptr) {
    sdl_panic();
  }

  return window;
}

Window::Window(const std::string title) {
  if (!SDL_Init(0)) {
    sdl_panic();
  }

  window = create_window(title);
}

Window::~Window() {
  SDL_DestroyWindow(window);
  SDL_Quit();
}

VkSurfaceKHR Window::surface(const VkInstance vk_instance) const {
  VkSurfaceKHR surface;
  SDL_Vulkan_CreateSurface(window, vk_instance, nullptr, &surface);

  return surface;
}

std::vector<const char *> Window::vulkan_instance_extensions() const {
  Uint32 extension_count;
  char const *const *extensions =
      SDL_Vulkan_GetInstanceExtensions(&extension_count);

  std::vector<const char *> extensions_vector;
  for (Uint32 i = 0; i < extension_count; i++) {
    extensions_vector.push_back(extensions[i]);
  }

  return extensions_vector;
}

void Window::start_event_loop(Graphics &graphics) const {
  bool is_running = true;
  while (is_running) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
      switch (event.type) {
      case SDL_EVENT_WINDOW_CLOSE_REQUESTED:
        is_running = false;
        break;
      case SDL_EVENT_WINDOW_RESIZED:
        graphics.should_recreate_swapchain = true;
        break;
      case SDL_EVENT_KEY_DOWN:
        if (event.key.key == SDLK_ESCAPE) {
          is_running = false;
        }
        break;
      }
    }

    if (graphics.should_recreate_swapchain) {
      graphics.recreate_rendering();
    }
    graphics.render();
  }
}
