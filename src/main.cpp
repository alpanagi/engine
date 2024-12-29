#include "sdlk.h"
#include "vlk.h"
#include <SDL3/SDL_main.h>
#include <print>

int main() {
  sdlk::initialize();
  vlk::create_instance();
}
