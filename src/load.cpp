#include "load.h"
#include "error.h"
#include <toml++/toml.h>

std::vector<Mesh> load::meshes() {
  std::vector<Mesh> meshes;

  toml::table toml = toml::parse_file("../game/meshes.toml");
  toml::node_view meshes_toml = toml["meshes"];

  if (!meshes_toml.is_array()) {
    panic("[TOML] Couldn't find array 'meshes' in 'meshes.toml'");
  }

  toml::array &meshes_arr = *meshes_toml.as_array();
  for (toml::node &mesh_node : meshes_arr) {
    if (!mesh_node.is_table()) {
      panic("[TOML] Mesh is not a table");
    }

    toml::table &mesh_toml = *mesh_node.as_table();

    Mesh mesh(mesh_toml["name"].value_or(""));
    meshes.push_back(mesh);
  }

  return meshes;
}

std::vector<Object> load::objects(const std::vector<Mesh> &meshes) {
  std::vector<Object> objects;

  toml::table toml = toml::parse_file("../game/objects.toml");
  toml::node_view objects_toml = toml["objects"];

  if (!objects_toml.is_array()) {
    panic("[TOML] Couldn't find array 'objects' in 'objects.toml'");
  }

  toml::array &objects_arr = *objects_toml.as_array();
  for (toml::node &object_node : objects_arr) {
    if (!object_node.is_table()) {
      panic("[TOML] Object is not a table");
    }

    toml::table &object_toml = *object_node.as_table();
    Object obj(object_toml["name"].value_or(""), meshes[0]);
    objects.push_back(obj);
  }

  return objects;
}
