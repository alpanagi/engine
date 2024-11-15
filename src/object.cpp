#include "object.h"

Object::Object(const std::string name, const Mesh &mesh)
    : mesh(mesh), name(name) {}
