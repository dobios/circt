//===- LCTypes.td - Lambda Calculus dialect types ----------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef CIRCT_DIALECT_LC_LCTYPES_TD
#define CIRCT_DIALECT_LC_LCTYPES_TD

include "circt/Dialect/LC/LCDialect.td"
include "mlir/IR/AttrTypeBase.td"

class LCTypeDef<string name, string typeMnemonic> : TypeDef<LCDialect, name> {
  let mnemonic = typeMnemonic;
}

def LCADTType : LCTypeDef<"ADT", "adt_type"> {
  let summary = "Algebraic Data Type";
  let description = [{
    Represents the parent ADT definition that an ADT case is tied to.
    This means that the type of an ADT case is an `!lc.adt_type<@parent_sym>`.
  }];

  let parameters  = (ins "::circt::InnerSymAttr":$adt_sym);
  let assemblyFormat = [{
    `<` $adt_sym `>`
  }];
}

def LCLambdaType : LCTypeDef<"Lambda", "lambda_type"> {
  let summary = "Lambda type";
  let description = [{
    Reprensents an anonymous function type.
    Operations of the lambda type can be used as arguments in other lambdas.
  }];

  let parameters = (ins ArrayRefParameter<"mlir::Type", "input types">:$inputTypes,
                        OptionalArrayRefParameter<"mlir::Type", "output types">:$outputTypes
  );
  let assemblyFormat = [{
    `<` `<` $inputTypes `>` (`,` `<` $outputTypes^ `>`)? `>`
  }];
}


#endif // CIRCT_DIALECT_LC_LCTYPES_TD

