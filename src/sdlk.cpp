#include "sdlk.h"
#include "panik.h"
#include <SDL3/SDL_video.h>
#include <SDL3/SDL_vulkan.h>

void sdlk::initialize() {
  if (!SDL_Init(0)) {
    panik::crash(panik::component::sdl, SDL_GetError());
  }
}

SDL_Window *sdlk::create_window(const std::string &title) {
  auto window = SDL_CreateWindow(title.c_str(), 800, 600, SDL_WINDOW_VULKAN);

  if (window == nullptr) {
    panik::crash(panik::component::sdl, SDL_GetError());
  }

  return window;
}

std::vector<std::string> sdlk::get_required_vulkan_extensions() {
  std::vector<std::string> string_extension_names;

  uint32_t count;
  auto extension_names = SDL_Vulkan_GetInstanceExtensions(&count);

  for (int i = 0; i < count; i++) {
    string_extension_names.emplace_back(extension_names[count]);
  }

  return string_extension_names;
}
