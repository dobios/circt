//===- HWToBTOR2.h - HW to BTOR2 conversion pass ----------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file declares passes which together will convert the HW dialect to a
// state transition system and emit it as a btor2 string.
//
//===----------------------------------------------------------------------===//

#ifndef CIRCT_CONVERSION_HWTOBTOR2_H
#define CIRCT_CONVERSION_HWTOBTOR2_H

#include <memory>

namespace mlir {
class Pass;
} // namespace mlir

namespace circt {
std::unique_ptr<mlir::Pass> createConvertHWToBTOR2Pass();

} // namespace circt

#endif // CIRCT_CONVERSION_HWTOBTOR2_H
