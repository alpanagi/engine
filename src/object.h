#ifndef _OBJECT_H_
#define _OBJECT_H_

#include "mesh.h"
#include <memory>
#include <string>

struct Object {
  const std::string name;
  const std::shared_ptr<const Mesh> mesh;

  Object(const std::string, std::shared_ptr<const Mesh>);
};

#endif
