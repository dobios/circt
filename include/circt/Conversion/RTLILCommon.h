#ifndef CIRCT_CONVERSION_RTLILCOMMON_H
#define CIRCT_CONVERSION_RTLILCOMMON_H

#include "circt/Dialect/HW/HWTypes.h"
#include "circt/Dialect/RTLIL/RTLIL.h"
#include "circt/Dialect/RTLIL/RTLILTypes.h"
#include "circt/Dialect/Seq/SeqTypes.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/IR/Value.h"
#include "mlir/Transforms/DialectConversion.h"
#include "llvm/Support/FormatVariadic.h"
#include "llvm/Support/raw_ostream.h"
#include <atomic>
#include <string>

namespace circt::rtlil {

inline static std::string asOperandRaw(const mlir::Value v) {
  std::string result;
  llvm::raw_string_ostream os(result);
  v.printAsOperand(os, {});
  return result;
}

template <typename Sym>
inline static mlir::Operation *lookupSymbolWalkTables(mlir::Operation *from,
                                                      const Sym &sym) {
  auto *op = from;
  mlir::Operation *result = nullptr;
  while (op) {
    if ((result = mlir::SymbolTable::lookupNearestSymbolFrom(op, sym))) {
      break;
    };
    op = op->getParentOp();
  }
  return result;
}

template <typename OpType, typename Sym>
inline static OpType lookupSymbolWalkTables(mlir::Operation *from,
                                            const Sym &sym) {
  auto *op = from;
  OpType result = nullptr;
  while (op) {
    if ((result =
             mlir::SymbolTable::lookupNearestSymbolFrom<OpType>(op, sym))) {
      break;
    };
    op = op->getParentOp();
  }
  return result;
}

struct ConversionPatternContext {
  std::unordered_map<int, std::pair<int, mlir::StringAttr>> portMap;
  llvm::DenseMap<mlir::Location, int> globalMap;
  std::atomic<unsigned int> nameCtr = 0;
  auto lock() { return std::lock_guard<std::recursive_mutex>(l); }

private:
  std::recursive_mutex l;
};

class RTLILTypeConverter : public mlir::TypeConverter {

  class RTLILSignatureConversion : public SignatureConversion {

  public:
    RTLILSignatureConversion(int n);
  };

  static std::optional<mlir::Type> convertInteger(mlir::IntegerType t);

  static std::optional<mlir::Type> convertInt(circt::hw::IntType t);

  static std::optional<mlir::Type> convertClock(circt::seq::ClockType t);

  static mlir::Value materializeInt(mlir::OpBuilder &builder,
                                    circt::rtlil::MValueType t,
                                    mlir::ValueRange vals, mlir::Location pos);

public:
  RTLILTypeConverter();
  void convertSignature() {}
};

template <typename T>
struct ConversionPatternBase : public OpConversionPattern<T> {
private:
  using Super = OpConversionPattern<T>;

protected:
  rtlil::ConversionPatternContext &rtlilContext;

public:
  ConversionPatternBase(const TypeConverter &typeConverter,
                        rtlil::ConversionPatternContext &rtlilContext,
                        mlir::MLIRContext *context)
      : Super(typeConverter, context), rtlilContext(rtlilContext) {}
  template <typename S>
  mlir::StringAttr getStr(S &&s) const {
    return mlir::StringAttr::get(Super::getContext(), s);
  }
  mlir::IntegerAttr getInt(int32_t i) const {
    return mlir::IntegerAttr::get(
        mlir::IntegerType::get(Super::getContext(), 32), i);
  }
  template <typename S>
  rtlil::ParameterAttr getParameter(S &&key, int32_t val) const {
    return rtlil::ParameterAttr::get(Super::getContext(), getStr(key),
                                     getInt(val));
  }
  template <typename S>
  rtlil::ParameterAttr getParameter(S &&key, mlir::IntegerAttr val) const {
    return rtlil::ParameterAttr::get(Super::getContext(), getStr(key), val);
  }

  template <typename S>
  mlir::StringAttr makeGlobal(mlir::ConversionPatternRewriter &r, S s,
                              Location loc) const {
    auto guard = rtlilContext.lock();
    auto [it, inserted] = rtlilContext.globalMap.insert({loc, 0});
    if (inserted) {
      it->second = ++rtlilContext.nameCtr;
    }
    auto res = llvm::formatv("\\{0}_{1}", s, it->second);
    return r.getStringAttr(res);
  }
  template <typename S>
  mlir::StringAttr makeLocal(mlir::ConversionPatternRewriter &r, S s) const {
    auto res = llvm::formatv("${0}", s);
    return r.getStringAttr(res);
  }
  mlir::StringAttr genLocal(mlir::ConversionPatternRewriter &r) const {
    auto v = ++rtlilContext.nameCtr;
    return r.getStringAttr(llvm::formatv("${0}", v));
  }
  mlir::StringAttr asOperand(mlir::ConversionPatternRewriter &r,
                             Value v) const {
    return r.getStringAttr(rtlil::asOperandRaw(v));
  }
};
} // namespace circt::rtlil

#endif