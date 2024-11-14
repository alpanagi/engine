#include <iostream>
#include <toml++/toml.h>
#include <vector>

void panic(std::string message) {
  std::cout << message << std::endl;
  exit(1);
}

struct Object {
  std::string name;
  std::string mesh;
};

std::vector<Object> load_objects() {
  std::vector<Object> objects;

  toml::table toml = toml::parse_file("../game/objects.toml");
  toml::node_view objects_toml = toml["objects"];

  if (!objects_toml.is_array()) {
    panic("Couldn't find array 'objects' in 'objects.toml'");
  }

  toml::array &objects_arr = *objects_toml.as_array();
  for (toml::node &object : objects_arr) {
    if (!object.is_table()) {
      panic("Object is not a table");
    }

    toml::table &object_toml = *object.as_table();

    Object obj;
    obj.name = object_toml["name"].value_or("");
    obj.mesh = object_toml["mesh"].value_or("");
    objects.push_back(obj);
  }

  return objects;
}

int main() {
  std::vector<Object> objects = load_objects();
  for (auto object : objects) {
    std::cout << "name: " << object.name << std::endl;
    std::cout << "mesh: " << object.mesh << std::endl;
  }
}
