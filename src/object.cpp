#include "object.h"

#include <memory>

Object::Object(const std::string name, std::shared_ptr<const Mesh> mesh)
    : mesh(mesh), name(name) {}
