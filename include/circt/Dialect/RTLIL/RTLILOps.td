#ifndef RTLIL_OPS
#define RTLIL_OPS

include "RTLIL.td"
include "mlir/Interfaces/SideEffectInterfaces.td"
include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/OpBase.td"
include "mlir/IR/OpAsmInterface.td"
include "mlir/IR/SymbolInterfaces.td"
include "mlir/IR/EnumAttr.td"
include "mlir/IR/BuiltinAttributeInterfaces.td"
include "mlir/IR/BuiltinTypes.td"
include "mlir/IR/CommonAttrConstraints.td"

//===----------------------------------------------------------------------===//
// RTLIL dialect definition.
//===----------------------------------------------------------------------===//

def RTLIL_Dialect : Dialect {
    let name = "rtlil";
    let summary = "A rtlil out-of-tree MLIR dialect.";
    let description = [{
        This dialect is minimal example to implement rtlil-world kind of sample code
        for MLIR.
    }];
    let cppNamespace = "::circt::rtlil";
    // let hasConstantMaterializer = 1;
    let useDefaultTypePrinterParser = 1;
    let useDefaultAttributePrinterParser = 1;
}

//===----------------------------------------------------------------------===//
// Base rtlil operation definition.
//===----------------------------------------------------------------------===//

class RTLIL_Op<string mnemonic, list<Trait> traits = []> :
        Op<RTLIL_Dialect, mnemonic, traits>;

class RTLIL_Attr<string attrName, string attrMnemonic, list<Trait> traits = []>
    : AttrDef<RTLIL_Dialect, attrName, traits> {
  let mnemonic = attrMnemonic;
}

class RTLIL_Type<string name, list<Trait> traits = []>
  : TypeDef<RTLIL_Dialect, name, traits> { }

// Parameters

def ParamAttr : RTLIL_Attr<"Parameter", "param"> {
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

def ParametersAttr
  : TypedArrayAttrBase<ParamAttr, "cell parameters"> {
  let constBuilderCall = "::circt::rtlil::createParamsAttr($_builder.getContext(), $0)";
}

// Connectivity

class I8EnumAttrCase<string sym, int val, string str = sym>
    : IntEnumAttrCaseBase<I8, sym, str, val>;
def StateS0: I8EnumAttrCase<"S0", 0>;
def StateS1: I8EnumAttrCase<"S1", 1>;
def StateSx: I8EnumAttrCase<"Sx", 2>;
def StateSz: I8EnumAttrCase<"Sz", 3>;
def StateSa: I8EnumAttrCase<"Sa", 4>;

class I8EnumAttr<string name, string summary, list<I8EnumAttrCase> cases> :
    IntEnumAttr<I8, name, summary, cases> {
  let underlyingType = "uint8_t";
}

def StateEnumAttr: I8EnumAttr<"StateEnum", "RTLIL::State model",
    [StateS0, StateS1, StateSx, StateSz, StateSa]> {
  let stringToSymbolFnName = "ConvertToEnum";
  let symbolToStringFnName = "ConvertToString";
  let cppNamespace = "::circt::rtlil";
}

// A parameterized integer type. Declares the hw::IntType in C++.
def MValueTypeImpl : RTLIL_Type<"MValue"> {
  let summary = "parameterized-width RTLIL::State sequence";
  let parameters = (ins "::mlir::TypedAttr":$width);
  let typeName = "rtlil.val";
  let assemblyFormat = "`[` $width `]`";
  let mnemonic = "val";
}

def RTLILValue : DialectType<RTLIL_Dialect, CPred<"::circt::rtlil::isMValueType($_self)">, "value">;

def ConstAttr
  : TypedArrayAttrBase<StateEnumAttr, "constant multi-valued bitvec">;

def ConstOp : RTLIL_Op<"const"> {
  let arguments = (ins ConstAttr:$value);
  let results = (outs RTLILValue:$result);
}

// TODO Is I32 correct?
def WireOp : RTLIL_Op<"wire"> {
  let arguments = (ins StrAttr:$name
                       ,I32Attr:$width
                       ,I32Attr:$start_offset
                       ,I32Attr:$port_id
                       ,DefaultValuedAttr<BoolAttr, "false">:$port_input
                       ,DefaultValuedAttr<BoolAttr, "false">:$port_output
                       ,DefaultValuedAttr<BoolAttr, "false">:$upto
                       ,BoolAttr:$is_signed
  );
  let results = (outs RTLILValue:$result);
}

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

def CellOp : RTLIL_Op<"cell", [DeclareOpInterfaceMethods<CellOpInterface>]> {
  let arguments = (ins StrAttr:$name
                       ,StrAttr:$type
                       ,Variadic<RTLILValue>:$connections
                       ,StrArrayAttr:$ports
                       ,ParametersAttr:$parameters
  );
}

class FixedOperands<int n> : AllMatch<["getNumOperands()", "" # n], "has " # n # " connections">;
class MValueExpander  {
  string typeName = MValueTypeImpl.cppType;
}

class FixedWidths<list<string> widths> : MValueExpander, TraitList<!foreach(idx, !range(widths), AllMatch<["::llvm::cast<::mlir::IntegerAttr>(::llvm::cast<"# typeName #">(getOperand(" # idx # ").getType()).getWidth()).getInt()", "" # widths[idx]], "input " # idx # " width is " # widths[idx]>)>;

def DFFOp : RTLIL_Op<"dff", [DeclareOpInterfaceMethods<CellOpInterface>, FixedOperands<3>, FixedWidths<["1", "$width", "$width"]>]> {
  let arguments = (ins StrAttr:$name,
                      Variadic<RTLILValue>:$connections,
                      I32Attr:$width,
                      DefaultValuedAttr<StrAttr, [{"$$dff"}]>:$type,
                      DefaultValuedAttr<StrArrayAttr, [{ {"\\CLK", "\\D", "\\Q"} }]>:$ports);
  DerivedAttr parameters = DerivedAttr<"::mlir::ArrayAttr", [{
                        return ::circt::rtlil::createParamsAttr(getContext(), {
                          {"\\WIDTH", 32, getWidth()},
                          {"\\CLK_POLARITY", 1, 1}
                        });
                      }], "getParameters()">;
}

def ALDFFOp : RTLIL_Op<"aldff", [DeclareOpInterfaceMethods<CellOpInterface>, FixedOperands<5>, FixedWidths<["1", "$width", "1", "$width", "$width"]>]> {
  let arguments = (ins StrAttr:$name,
                      Variadic<RTLILValue>:$connections,
                      I32Attr:$width,
                      DefaultValuedAttr<StrAttr, [{"$$aldff"}]>:$type,
                      DefaultValuedAttr<StrArrayAttr, [{ {"\\CLK", "\\D", "\\ALOAD", "\\AD", "\\Q"} }]>:$ports);
  DerivedAttr parameters = DerivedAttr<"::mlir::ArrayAttr", [{
                        return ::circt::rtlil::createParamsAttr(getContext(), {
                          {"\\WIDTH", 32, getWidth()},
                          {"\\CLK_POLARITY", 1, 1},
                          {"\\ALOAD_POLARITY", 1, 1},
                        });
                      }], "getParameters()">;
}

def IntanceOp : RTLIL_Op<"instance", [DeclareOpInterfaceMethods<CellOpInterface>]> {
  let arguments = (ins StrAttr:$name,
                       FlatSymbolRefAttr:$type,
                       Variadic<RTLILValue>:$connections,
                       StrArrayAttr:$ports,
                       ParametersAttr:$parameters
  );
}

def WConnectionOp : RTLIL_Op<"wconnection"> {
  let arguments = (ins RTLILValue:$lhs, RTLILValue:$rhs);
}
                      //  , // TODO back to FlatSymbolRefAttr?
  // let results = (outs Variadic<AnyType>:$results);

#endif // RTLIL_OPS