#include "circt/Dialect/RTLIL/RTLILTypes.h"
#include "circt/Dialect/RTLIL/RTLIL.h"
#include "circt/Dialect/RTLIL/RTLILOps.h"
#include "mlir/IR/Attributes.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/OpImplementation.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringRef.h"
#include <tuple>

using namespace mlir;

namespace circt::rtlil {
bool isMValueType(mlir::Type type) {
  if (isa<MValueType>(type))
    return true;
  return false;
}

ArrayAttr createParamsAttr(
    mlir::MLIRContext *context,
    llvm::ArrayRef<std::tuple<llvm::StringRef, unsigned, uint64_t>> &&r) {
  llvm::SmallVector<Attribute, 5> v;
  for (auto &&[name, width, val] : r) {
    v.emplace_back(ParameterAttr::get(context, name, width, val));
  }
  return ArrayAttr::get(context, v);
}
} // namespace circt::rtlil