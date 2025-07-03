#include "circt/Dialect/RTLIL/RTLILTypes.h"
#include "circt/Dialect/RTLIL/RTLILOps.h"
#include "mlir/IR/OpImplementation.h"

using namespace mlir;

namespace circt::rtlil {
bool isMValueType(mlir::Type type) {
    if (isa<MValueType>(type))
        return true;
    return false;
}
} // namespace rtlil