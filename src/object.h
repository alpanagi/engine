#ifndef _OBJECT_H_
#define _OBJECT_H_

#include "mesh.h"
#include <string>

struct Object {
  const std::string name;
  const Mesh &mesh;

  Object(const std::string, const Mesh &);
};

#endif
