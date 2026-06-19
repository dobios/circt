//===- RTLILEnums.td - Enums for RTLIL dialect -------------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines RTLIL dialect specific enums.
//
//===----------------------------------------------------------------------===//

#ifndef CIRCT_DIALECT_RTLIL_RTLILENUMS_TD
#define CIRCT_DIALECT_RTLIL_RTLILENUMS_TD

include "mlir/IR/EnumAttr.td"

let cppNamespace = "circt::rtlil" in {

//----------------------------------------------------------------------------//
// Special definition for small enums
//----------------------------------------------------------------------------//

class I8EnumAttrCase<string sym, int val, string str = sym>
    : IntEnumAttrCaseBase<I8, sym, str, val>;

class I8EnumAttr<string name, string summary, list<I8EnumAttrCase> cases> :
    IntEnumAttr<I8, name, summary, cases> {
  let underlyingType = "uint8_t";
}

//----------------------------------------------------------------------------//
// Signedness of an rtlil wire
//----------------------------------------------------------------------------//

/// Signed means that the contens of the wire must be interpreted
def Signed : I8EnumAttrCase<"Signed", 1, "signed">;
/// Unsigned means that the contents are just raw bits
def Unsigned : I8EnumAttrCase<"AtNegEdge", 0, "negedge">;

def Signedness : I8EnumAttr<"Signedness", "signedness of an rtlil wire",
                                   [Signed, Unsigned]>;


//----------------------------------------------------------------------------//
// Direction of an rtlil wire port
//----------------------------------------------------------------------------//

/// Wires can also be ports: In, Out, or InOut
def Input : I8EnumAttrCase<"Input", 0, "in">;
def Output : I8EnumAttrCase<"Output", 1, "out">;
def InputOutput : I8EnumAttrCase<"InputOutput", 2, "inout">;

def PortDirection : I8EnumAttr<"PortDirection", "Direction of a wire port",
                                   [Input, Output, InputOutput]>;

//----------------------------------------------------------------------------//
// RTLIL State model
//----------------------------------------------------------------------------//

/// States can take values 0/1/X/Z/A in RTLIL
def StateS0: I8EnumAttrCase<"S0", 0>;
def StateS1: I8EnumAttrCase<"S1", 1>;
def StateSx: I8EnumAttrCase<"Sx", 2>;
def StateSz: I8EnumAttrCase<"Sz", 3>;
def StateSa: I8EnumAttrCase<"Sa", 4>;

def StateEnumAttr: I8EnumAttr<"StateEnum", "RTLIL::State model",
    [StateS0, StateS1, StateSx, StateSz, StateSa]> {
  let stringToSymbolFnName = "ConvertToEnum";
  let symbolToStringFnName = "ConvertToString";
  let cppNamespace = "::circt::rtlil";
}

} // namspace circt::rtlil

#endif // CIRCT_DIALECT_RTLIL_RTLILENUMS_TD
