#ifndef CIRCT_CONVERSION_HWTORTLIL_H
#define CIRCT_CONVERSION_HWTORTLIL_H

#include "circt/Support/LLVM.h"
#include "llvm/ADT/SmallVector.h"
#include <memory>

namespace circt {

#define GEN_PASS_DECL_CONVERTHWTORTLIL
#include "circt/Conversion/Passes.h.inc"

} // namespace circt
#endif
