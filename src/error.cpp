#include "error.h"
#include <iostream>

void panic(const std::string msg) {
  std::cout << "[ENGINE] " << msg << std::endl;
  exit(1);
}
