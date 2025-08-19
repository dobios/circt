#ifndef CIRCT_DIALECT_RTLIL_RTLILTYPES_H
#define CIRCT_DIALECT_RTLIL_RTLILTYPES_H

#include "RTLIL.h"
#include "mlir/TableGen/Type.h"

namespace circt::rtlil {
bool isMValueType(mlir::Type type);
mlir::ArrayAttr createParamsAttr(
    mlir::MLIRContext *context,
    llvm::ArrayRef<std::tuple<llvm::StringRef, unsigned, uint64_t>> &&r);
}; // namespace circt::rtlil

#endif