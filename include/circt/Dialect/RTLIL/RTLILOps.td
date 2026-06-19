#ifndef RTLIL_OPS
#define RTLIL_OPS

include "mlir/Interfaces/SideEffectInterfaces.td"
include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/OpBase.td"
include "mlir/IR/OpAsmInterface.td"
include "mlir/IR/SymbolInterfaces.td"
include "mlir/IR/EnumAttr.td"
include "mlir/IR/BuiltinAttributeInterfaces.td"
include "mlir/IR/BuiltinTypes.td"
include "mlir/IR/CommonAttrConstraints.td"

include "RTLIL.td"
include "circt/Dialect/RTLIL/RTLILDialect.td"
include "circt/Dialect/RTLIL/RTLILEnums.td"
include "circt/Dialect/RTLIL/RTLILTypes.td"
include "circt/Dialect/RTLIL/RTLILAttributes.td"

//===----------------------------------------------------------------------===//
// Base class definitions
//===----------------------------------------------------------------------===//

class RTLILOp<string mnemonic, list<Trait> traits = []> :
        Op<RTLILDialect, mnemonic, traits>;


//===----------------------------------------------------------------------===//
// Wire related operations and primitives
//===----------------------------------------------------------------------===//

def ConstOp : MValueExpander, RTLILOp<"const", [AllMatch<["llvm::cast<mlir::IntegerAttr>(llvm::cast<mlir::TypedValue<" # typeName # ">>($result).getType().getWidth()).getValue()", "$value.size()"], "bitwidth matches">]> {
  let arguments = (ins ConstAttr:$value);
  let results = (outs RTLILValue:$result);
}

// TODO Is I32 correct?
def WireOp : RTLILOp<"wire"> {
  let arguments = (ins StrAttr:$name
                       ,BoolAttr:$is_signed
                       ,DefaultValuedAttr<I32Attr, "0">:$port_id
                       ,DefaultValuedAttr<I32Attr, "0">:$start_offset
                       ,DefaultValuedAttr<BoolAttr, "false">:$port_input
                       ,DefaultValuedAttr<BoolAttr, "false">:$port_output
                       ,DefaultValuedAttr<BoolAttr, "false">:$upto
  );
  DerivedAttr width = DerivedAttr<"::mlir::IntegerAttr", [{
        return mlir::IntegerAttr::get(mlir::IntegerType::get(getContext(), 32), llvm::cast<mlir::IntegerAttr>(llvm::cast<rtlil::MValueType>(this->getResult().getType()).getWidth()).getValue());
                          }], "getWidth()">;
  let results = (outs RTLILValue:$result);
}

//===----------------------------------------------------------------------===//
// Cell related operations 
//===----------------------------------------------------------------------===//


def CellOpInterface : OpInterface<"CellOpInterface"> {
  let description = [{
    All cell types implement this interface.
  }];
  let cppNamespace = "::circt::rtlil";
  let methods = [
    InterfaceMethod<[{
      Gets the name of the cell op.
    }], "::llvm::StringRef", "getCellName", (ins),
    /*methodBody*/ "",
    /*defaultImpl*/ [{
      return $_op.getName();
    }]>,
    InterfaceMethod<[{
      Gets the type of the cell op.
    }], "::llvm::StringRef", "getCellType", (ins),
    "", [{
      return $_op.getType();
    }]>,
    InterfaceMethod<[{
      Gets the connections of the cell op.
    }], "::mlir::OperandRange", "getCellConnections", (ins),
    "", [{
      return $_op.getConnections();
    }]>,
    InterfaceMethod<[{
      Gets the Ports of the cell op.
    }], "::mlir::ArrayAttr", "getCellPorts", (ins),
    "", [{
      return $_op.getPorts();
    }]>,
    InterfaceMethod<[{
      Gets the parameters of the cell op.
    }], "::mlir::ArrayAttr", "getCellParameters", (ins),
    "", [{
      return $_op.getParameters();
    }]>
  ];
}

def CellOp : RTLILOp<"cell", [DeclareOpInterfaceMethods<CellOpInterface>]> {
  let arguments = (ins StrAttr:$name
                       ,StrAttr:$type
                       ,Variadic<RTLILValue>:$connections
                       ,StrArrayAttr:$ports
                       ,ParamArrayAttr:$parameters
  );
}

class FixedOperands<int n> : AllMatch<["getNumOperands()", "" # n], "has " # n # " connections">;


class FixedWidths<list<string> widths> : MValueExpander, TraitList<!foreach(idx, !range(widths), AllMatch<["::llvm::cast<::mlir::IntegerAttr>(::llvm::cast<"# typeName #">(getOperand(" # idx # ").getType()).getWidth()).getInt()", "" # widths[idx]], "input " # idx # " width is " # widths[idx]>)>;

class BinOp<string t> : RTLILOp<t, [DeclareOpInterfaceMethods<CellOpInterface>, FixedOperands<3>, FixedWidths<["$width", "$width", "$width"]>]> {
  let arguments = (ins StrAttr:$name,
                      Variadic<RTLILValue>:$connections,
                      I32Attr:$width,
                      I32Attr:$opsSigned,
                      DefaultValuedAttr<StrAttr, [{"$$}] # t # [{"}]>:$type,
                      DefaultValuedAttr<StrArrayAttr, [{ {"\\A", "\\B", "\\Y"} }]>:$ports);
  DerivedAttr parameters = DerivedAttr<"::mlir::ArrayAttr", [{
                            return ::circt::rtlil::createParamArrayAttr(getContext(), {
                              {"\\A_SIGNED", 32, getOpsSigned()},
                              {"\\B_SIGNED", 32, getOpsSigned()},
                              {"\\A_WIDTH", 32, getWidth()},
                              {"\\B_WIDTH", 32, getWidth()},
                              {"\\Y_WIDTH", 32, getWidth()},
                            });
                          }], "getParameters()">;
}

def AndOp : BinOp<"and">;
def OrOp  : BinOp<"or">;
def AddOp : BinOp<"add">;
def SubOp : BinOp<"sub">;

def MuxOp : RTLILOp<"mux", [DeclareOpInterfaceMethods<CellOpInterface>, FixedOperands<4>, FixedWidths<["$width", "$width", "1", "$width"]>]> {
  let arguments = (ins StrAttr:$name,
                      Variadic<RTLILValue>:$connections,
                      I32Attr:$width,
                      DefaultValuedAttr<StrAttr, [{"$$mux"}]>:$type,
                      DefaultValuedAttr<StrArrayAttr, [{ {"\\A", "\\B", "\\S", "\\Y"} }]>:$ports);
  DerivedAttr parameters = DerivedAttr<"::mlir::ArrayAttr", [{
                            return ::circt::rtlil::createParamArrayAttr(getContext(), {
                              {"\\WIDTH", 32, getWidth()},
                            });
                          }], "getParameters()">;
}

class CmpOp<string t> : RTLILOp<t, [DeclareOpInterfaceMethods<CellOpInterface>, FixedOperands<3>, FixedWidths<["$width", "$width", "1"]>]> {
  let arguments = (ins StrAttr:$name,
                      Variadic<RTLILValue>:$connections,
                      I32Attr:$width,
                      I32Attr:$opsSigned,
                      DefaultValuedAttr<StrAttr, [{"$$}] # t # [{"}]>:$type,
                      DefaultValuedAttr<StrArrayAttr, [{ {"\\A", "\\B", "\\Y"} }]>:$ports);
  DerivedAttr parameters = DerivedAttr<"::mlir::ArrayAttr", [{
                            return ::circt::rtlil::createParamArrayAttr(getContext(), {
                              {"\\A_SIGNED", 32, getOpsSigned()},
                              {"\\B_SIGNED", 32, getOpsSigned()},
                              {"\\A_WIDTH", 32, getWidth()},
                              {"\\B_WIDTH", 32, getWidth()},
                              {"\\Y_WIDTH", 32, 1},
                            });
                          }], "getParameters()">;
}

def GTOp : CmpOp<"gt">;
def EQOp : CmpOp<"eq">;
def NEOp : CmpOp<"ne">;
def GEOp : CmpOp<"ge">;
def LEOp : CmpOp<"le">;
def LTOp : CmpOp<"lt">;

def DFFOp : RTLILOp<"dff", [DeclareOpInterfaceMethods<CellOpInterface>, FixedOperands<3>, FixedWidths<["1", "$width", "$width"]>]> {
  let arguments = (ins StrAttr:$name,
                      Variadic<RTLILValue>:$connections,
                      I32Attr:$width,
                      DefaultValuedAttr<StrAttr, [{"$$dff"}]>:$type,
                      DefaultValuedAttr<StrArrayAttr, [{ {"\\CLK", "\\D", "\\Q"} }]>:$ports);
  DerivedAttr parameters = DerivedAttr<"::mlir::ArrayAttr", [{
                        return ::circt::rtlil::createParamArrayAttr(getContext(), {
                          {"\\WIDTH", 32, getWidth()},
                          {"\\CLK_POLARITY", 32, 1}
                        });
                      }], "getParameters()">;
}

def SliceOp : RTLILOp<"slice", [DeclareOpInterfaceMethods<CellOpInterface>, FixedOperands<2>, FixedWidths<["$widthA", "$widthY"]>]> {
  let arguments = (ins StrAttr:$name,
                      Variadic<RTLILValue>:$connections,
                      I32Attr:$widthA,
                      I32Attr:$widthY,
                      I32Attr:$offset,
                      DefaultValuedAttr<StrAttr, [{"$$slice"}]>:$type,
                      DefaultValuedAttr<StrArrayAttr, [{ {"\\A", "\\Y"} }]>:$ports);
  DerivedAttr parameters = DerivedAttr<"::mlir::ArrayAttr", [{
                            return ::circt::rtlil::createParamArrayAttr(getContext(), {
                              {"\\OFFSET", 32, getOffset()},
                              {"\\A_WIDTH", 32, getWidthA()},
                              {"\\Y_WIDTH", 32, getWidthY()},
                            });
                          }], "getParameters()">;
}

def ConcatOp : RTLILOp<"concat", [DeclareOpInterfaceMethods<CellOpInterface>, FixedOperands<3>, FixedWidths<["$widthA", "$widthB", "::llvm::cast<::mlir::IntegerAttr>(getWidthY()).getInt()"]>]> {
  let arguments = (ins StrAttr:$name,
                Variadic<RTLILValue>:$connections,
                              I32Attr:$widthA,
                              I32Attr:$widthB,
                              DefaultValuedAttr<StrAttr, [{"$$concat"}]>:$type,
                              DefaultValuedAttr<StrArrayAttr, [{ {"\\A", "\\B", "\\Y"} }]>:$ports);
  DerivedAttr widthY = DerivedAttr<"::mlir::IntegerAttr", [{
    return mlir::IntegerAttr::get(mlir::IntegerType::get(getContext(), 32), getWidthA() + getWidthB());
  }], "getWidthY()">;
  DerivedAttr parameters = DerivedAttr<"::mlir::ArrayAttr", [{
                            return ::circt::rtlil::createParamArrayAttr(getContext(), {
                              {"\\A_WIDTH", 32, getWidthA()},
                              {"\\B_WIDTH", 32, getWidthB()},
                            });
                              }], "getParameters()">;
}

def ALDFFOp : RTLILOp<"aldff", [DeclareOpInterfaceMethods<CellOpInterface>, FixedOperands<5>, FixedWidths<["1", "$width", "1", "$width", "$width"]>]> {
  let arguments = (ins StrAttr:$name,
                      Variadic<RTLILValue>:$connections,
                      I32Attr:$width,
                      DefaultValuedAttr<StrAttr, [{"$$aldff"}]>:$type,
                      DefaultValuedAttr<StrArrayAttr, [{ {"\\CLK", "\\D", "\\ALOAD", "\\AD", "\\Q"} }]>:$ports);
  DerivedAttr parameters = DerivedAttr<"::mlir::ArrayAttr", [{
                        return ::circt::rtlil::createParamArrayAttr(getContext(), {
                          {"\\WIDTH", 32, getWidth()},
                          {"\\CLK_POLARITY", 32, 1},
                          {"\\ALOAD_POLARITY", 32, 1},
                        });
                      }], "getParameters()">;
}

def IntanceOp : RTLILOp<"instance", [DeclareOpInterfaceMethods<CellOpInterface>]> {
  let arguments = (ins StrAttr:$name,
                       FlatSymbolRefAttr:$type,
                       Variadic<RTLILValue>:$connections,
                       StrArrayAttr:$ports,
                       ParamArrayAttr:$parameters
  );
}

def WConnectionOp : RTLILOp<"wconnection"> {
  let arguments = (ins RTLILValue:$lhs, RTLILValue:$rhs);
}
                      //  , // TODO back to FlatSymbolRefAttr?
  // let results = (outs Variadic<AnyType>:$results);

#endif // RTLIL_OPS
