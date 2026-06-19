//===- RTLILTypes.td - RTLIL dialect types -----------------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef CIRCT_DIALECT_RTLIL_RTLILTYPES_TD
#define CIRCT_DIALECT_RTLIL_RTLILTYPES_TD

include "mlir/IR/AttrTypeBase.td"
include "circt/Dialect/RTLIL/RTLILDialect.td"

/// Base type for all RTLIL objects
class RTLILType<string name, list<Trait> traits = []>
  : TypeDef<RTLILDialect, name, traits> { }

/// All Values in RTLIL must pass of MValueType check
def RTLILValue : DialectType<
  RTLILDialect, 
  CPred<"::circt::rtlil::isMValueType($_self)">, 
  "value"
>;

class MValueExpander  {
  string typeName = MValueTypeImpl.cppType;
}

// A parameterized integer type. Declares the hw::IntType in C++.
def MValueTypeImpl : RTLILType<"MValue"> {
  let summary = "parameterized-width RTLIL::State sequence";
  let parameters = (ins "::mlir::TypedAttr":$width);
  let typeName = "rtlil.val";
  let assemblyFormat = "`[` $width `]`";
  let mnemonic = "val";
}

#endif // CIRCT_DIALECT_RTLIL_RTLILTYPES_TD
