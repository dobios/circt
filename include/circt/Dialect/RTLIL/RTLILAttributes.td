//===- RTLILAttributes.td - Attributes for RTLIL dialect ---*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines RTLIL dialect specific attributes.
//
//===----------------------------------------------------------------------===//

#ifndef CIRCT_DIALECT_RTLIL_RTLILATTRIBUTES_TD
#define CIRCT_DIALECT_RTLIL_RTLILATTRIBUTES_TD

include "mlir/IR/BuiltinAttributeInterfaces.td"
include "mlir/IR/BuiltinTypes.td"
include "mlir/IR/AttrTypeBase.td"

include "RTLIL.td"
include "circt/Dialect/RTLIL/RTLILDialect.td"
include "circt/Dialect/RTLIL/RTLILEnums.td"
include "circt/Dialect/RTLIL/RTLILTypes.td"

//===----------------------------------------------------------------------===//
// Base Attribute
//===----------------------------------------------------------------------===//

class RTLILAttr<string attrName, string attrMnemonic, list<Trait> traits = []>
    : AttrDef<RTLILDialect, attrName, traits> {
  let mnemonic = attrMnemonic;
}

//===----------------------------------------------------------------------===//
// Parameter Attributes
//===----------------------------------------------------------------------===//

def ParamAttr : RTLILAttr<"Parameter", "param"> {
  let parameters = (ins
                    "::mlir::StringAttr":$name,
                    "::mlir::IntegerAttr":$value);
  let assemblyFormat = "$name $value ";
  let builders = [
    AttrBuilder<(ins "llvm::StringRef":$name, "unsigned":$width,"uint64_t":$val), [{
      auto intattr = mlir::IntegerAttr::get(mlir::IntegerType::get($_ctxt, width), val);
      auto strattr = mlir::StringAttr::get($_ctxt, name);
      return Base::get($_ctxt, strattr, intattr);
    }]>
  ];
}

def ParamArrayAttr
  : TypedArrayAttrBase<ParamAttr, "cell parameters"> {
  let constBuilderCall = "::circt::rtlil::createParamArrayAttr($_builder.getContext(), $0)";
}

//===----------------------------------------------------------------------===//
// Connectivity Attributes
//===----------------------------------------------------------------------===//

def ConstAttr
  : TypedArrayAttrBase<StateEnumAttr, "constant multi-valued bitvec">;


#endif // CIRCT_DIALECT_RTLIL_RTLILATTRIBUTES_TD
