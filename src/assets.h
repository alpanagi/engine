#ifndef _ASSETS_H_
#define _ASSETS_H_

#include <string>
#include <vector>

namespace assets {
namespace shaders {
std::vector<char> load(const std::string &filename);
}
} // namespace assets

#endif
