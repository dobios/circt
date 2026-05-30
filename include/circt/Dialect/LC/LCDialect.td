//===- LCDialect.td - Lamda Calculus dialect definition ----*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef CIRCT_DIALECT_LC_LCDIALECT_TD
#define CIRCT_DIALECT_LC_LCDIALECT_TD

include "mlir/IR/OpBase.td"

def LCDialect : Dialect {
  let name = "lc";
  let summary = "Lamdas, Algebraic Data Types, and Recursion.";
  // See `docs/Dialect/LC.md` for detailed dialect documentation.
  let cppNamespace = "circt::lc";
}

#endif // CIRCT_DIALECT_LC_LCDIALECT_TD

