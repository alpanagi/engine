#ifndef _LOADER_H_
#define _LOADER_H_

#include "mesh.h"
#include "object.h"
#include <memory>
#include <vector>

namespace load {
std::vector<std::shared_ptr<const Mesh>> meshes();
std::vector<Object>
objects(const std::vector<std::shared_ptr<const Mesh>> &meshes);
} // namespace load

#endif
