//===- CombToSMT.cpp ------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "circt/Conversion/CombToRTLIL.h"
#include "circt/Dialect/Comb/CombDialect.h"
#include "circt/Dialect/Comb/CombOps.h"
#include "circt/Dialect/HW/HWOps.h"
#include "circt/Dialect/HW/HWTypes.h"
#include "circt/Dialect/RTLIL/RTLIL.h"
#include "circt/Support/LLVM.h"
#include "circt/Support/Naming.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Types.h"
#include "mlir/IR/ValueRange.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Transforms/DialectConversion.h"
#include "llvm/ADT/PointerUnion.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/LogicalResult.h"
#include <cstdint>
#include <optional>

namespace circt {
#define GEN_PASS_DEF_CONVERTCOMBTORTLIL
#include "circt/Conversion/Passes.h.inc"
} // namespace circt

using namespace circt;
using namespace comb;

//===----------------------------------------------------------------------===//
// Conversion patterns
//===----------------------------------------------------------------------===//

class RTLILTypeConverter : public mlir::TypeConverter {

  class RTLILSignatureConversion : public SignatureConversion {

  public:
    RTLILSignatureConversion(int n) : SignatureConversion(n) {}
  };

  static std::optional<mlir::Type> convertInteger(mlir::IntegerType t) {
    auto val = t.getWidth();
    if (val >= INT32_MAX) {
      return std::nullopt;
    }
    return rtlil::MValueType::get(
        t.getContext(), mlir::IntegerAttr::get(
                            mlir::IntegerType::get(t.getContext(), 32), val));
  }

  static std::optional<mlir::Type> convertInt(hw::IntType t) {
    auto width = cast<mlir::IntegerAttr>(t.getWidth());
    auto val = width.getInt();
    if (val >= INT32_MAX) {
      return std::nullopt;
    }
    return rtlil::MValueType::get(
        t.getContext(), mlir::IntegerAttr::get(
                            mlir::IntegerType::get(t.getContext(), 32), val));
  }

  static Value materializeInt(mlir::OpBuilder &builder, rtlil::MValueType t,
                              mlir::ValueRange vals, Location pos) {
    bool is_input = vals.empty();
    return builder.create<rtlil::WireOp>(
        pos, t, "wire", cast<mlir::IntegerAttr>(t.getWidth()).getInt(), 0, 0,
        is_input, 0, 0, 0);
  }

public:
  RTLILTypeConverter() : mlir::TypeConverter() {
    addConversion(convertInt);
    addConversion(convertInteger);
    addTargetMaterialization(materializeInt);
  }

  void convertSignature() {}
};

namespace {
struct CombAndOpConversion : OpConversionPattern<AndOp> {
  using OpConversionPattern<AndOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(AndOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    if (op.getNumOperands() != 2)
      return failure();

    auto resultWire = getTypeConverter()->materializeTargetConversion(
        rewriter, op->getLoc(),
        getTypeConverter()->convertType(op->getResultTypes().front()),
        op->getResult(0));
    std::vector<Value> connections(
        {adaptor.getInputs()[0], adaptor.getInputs()[1], resultWire});
    rewriter.create<rtlil::CellOp>(
        op.getLoc(), "and", "$and", std::move(connections),
        rewriter.getArrayAttr({}), rewriter.getArrayAttr({}));
    rewriter.replaceOp(op, resultWire);
    return success();
  }
};

struct ModuleConversion : OpConversionPattern<hw::HWModuleOp> {
  using OpConversionPattern<hw::HWModuleOp>::OpConversionPattern;
  LogicalResult
  matchAndRewrite(hw::HWModuleOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    if (!op.getBody().hasOneBlock()) {
      return failure();
    }
    auto result = rewriter.create<mlir::ModuleOp>(op.getLoc(),
                                                  op->getName().getStringRef());
    mlir::TypeConverter::SignatureConversion converter(op.getNumInputPorts());
    for (size_t input = 0; input < op.getNumInputPorts(); input++) {
      rewriter.setInsertionPoint(result.getBody(), result.getBody()->begin());
      Value replacement = getTypeConverter()->materializeTargetConversion(
          rewriter, op->getLoc(),
          getTypeConverter()->convertType(op.getInputTypes()[input]), {});
      auto wire = replacement.getDefiningOp<rtlil::WireOp>();
      wire.setPortId(input);
      converter.remapInput(input, replacement);
    }
    rewriter.applySignatureConversion(op.getBodyBlock(), converter,
                                      getTypeConverter());
    rewriter.inlineBlockBefore(&op.getBody().getBlocks().front(),
                               result.getBody(), result.getBody()->end());
    rewriter.replaceOp(op, result);
    return success();
  }
};
} // namespace

struct OutputConversion : OpConversionPattern<hw::OutputOp> {
  using OpConversionPattern<hw::OutputOp>::OpConversionPattern;
  LogicalResult
  matchAndRewrite(hw::OutputOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    rewriter.eraseOp(op);
    return success();
  }
};

//===----------------------------------------------------------------------===//
// Convert Comb to SMT pass
//===----------------------------------------------------------------------===//

namespace {
struct ConvertCombToRTLILPass
    : public circt::impl::ConvertCombToRTLILBase<ConvertCombToRTLILPass> {
  void runOnOperation() override;
};
} // namespace

static void populateCombToRTLILConversionPatterns(TypeConverter &converter,
                                                  RewritePatternSet &patterns) {
  patterns.add<ModuleConversion, OutputConversion, CombAndOpConversion>(
      converter, patterns.getContext());
}

void ConvertCombToRTLILPass::runOnOperation() {
  ConversionTarget target(getContext());

  target.addLegalDialect<rtlil::RTLILDialect>();
  target.addIllegalDialect<comb::CombDialect>();
  target.addLegalOp<mlir::ModuleOp>();

  RewritePatternSet patterns(&getContext());
  RTLILTypeConverter converter;
  populateCombToRTLILConversionPatterns(converter, patterns);

  if (failed(mlir::applyPartialConversion(getOperation(), target,
                                          std::move(patterns)))) {
    return signalPassFailure();
  }
}
