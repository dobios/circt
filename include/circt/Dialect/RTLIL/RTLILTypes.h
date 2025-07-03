#ifndef RTLIL_RTLILTYPES_H
#define RTLIL_RTLILTYPES_H

#include "mlir/TableGen/Type.h"
#include "RTLIL.h"

namespace circt::rtlil {
bool isMValueType(mlir::Type type);
}; // namespace rtlil

#endif