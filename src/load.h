#ifndef _LOADER_H_
#define _LOADER_H_

#include "mesh.h"
#include "object.h"
#include <vector>

namespace load {
std::vector<Mesh> meshes();
std::vector<Object> objects(const std::vector<Mesh> &meshes);
} // namespace load

#endif
