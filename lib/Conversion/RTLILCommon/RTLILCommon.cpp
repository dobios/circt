#include "circt/Conversion/RTLILCommon.h"
#include "circt/Dialect/RTLIL/RTLIL.h"
#include "circt/Support/LLVM.h"
#include "llvm/Support/FormatVariadic.h"

namespace circt::rtlil {

std::optional<mlir::Type>
RTLILTypeConverter::convertInteger(mlir::IntegerType t) {
  auto val = t.getWidth();
  if (val >= INT32_MAX) {
    return std::nullopt;
  }
  return rtlil::MValueType::get(
      t.getContext(),
      mlir::IntegerAttr::get(mlir::IntegerType::get(t.getContext(), 32), val));
}
std::optional<mlir::Type> RTLILTypeConverter::convertInt(circt::hw::IntType t) {
  auto width = cast<mlir::IntegerAttr>(t.getWidth());
  auto val = width.getInt();
  if (val >= INT32_MAX) {
    return std::nullopt;
  }
  return rtlil::MValueType::get(
      t.getContext(),
      mlir::IntegerAttr::get(mlir::IntegerType::get(t.getContext(), 32), val));
}

std::optional<mlir::Type>
RTLILTypeConverter::convertClock(circt::seq::ClockType t) {
  return rtlil::MValueType::get(
      t.getContext(),
      mlir::IntegerAttr::get(mlir::IntegerType::get(t.getContext(), 32), 1));
}

mlir::Value RTLILTypeConverter::materializeInt(mlir::OpBuilder &builder,
                                               circt::rtlil::MValueType t,
                                               mlir::ValueRange vals,
                                               mlir::Location pos) {
  bool isInput = vals.empty();
  if (vals.size() > 1) {
    return {};
  }
  mlir::StringAttr name = builder.getStringAttr("undefined");
  if (!isInput) {
    name = builder.getStringAttr(llvm::formatv("${0}", asOperandRaw(vals[0])));
  }

  return builder.create<rtlil::WireOp>(pos, t, name, 0, 0, 0, isInput, 0, 0);
}

RTLILTypeConverter::RTLILTypeConverter() : mlir::TypeConverter() {
  addConversion(convertInt);
  addConversion(convertInteger);
  addConversion(convertClock);
  addTargetMaterialization(materializeInt);
}

} // namespace circt::rtlil
