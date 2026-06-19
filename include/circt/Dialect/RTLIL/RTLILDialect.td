//===- RTLILDialect.td - RTLIL dialect definition ----------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// RTLIL dialect definition.
//
//===----------------------------------------------------------------------===//

#ifndef CIRCT_DIALECT_RTLIL_RTLILDIALECT_TD
#define CIRCT_DIALECT_RTLIL_RTLILDIALECT_TD

include "mlir/IR/OpBase.td"

def RTLILDialect : Dialect {
    let name = "rtlil";
    let summary = "Types and operations for RTLIL dialect";
    let description = [{
        This dialect deifnes the `rtlil` dialect, which is used to translate
        between CIRCT and Yosys. For more information, see the [RTLIL
        description](https://yosyshq.readthedocs.io/projects/yosys/en/latest/yosys_internals/formats/rtlil_rep.html).
    }];
    let cppNamespace = "::circt::rtlil";
    // let hasConstantMaterializer = 1;
    let useDefaultTypePrinterParser = 1;
    let useDefaultAttributePrinterParser = 1;
}

#endif // CIRCT_DIALECT_RTLIL_RTLILDIALECT_TD