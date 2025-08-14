//===- CombToRTLIL.cpp ----------------------------------------------------===//
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
#include "circt/Dialect/Seq/SeqDialect.h"
#include "circt/Dialect/Seq/SeqOps.h"
#include "circt/Dialect/Seq/SeqTypes.h"
#include "circt/Support/LLVM.h"
#include "circt/Support/Naming.h"
#include "mlir-c/BuiltinAttributes.h"
#include "mlir/IR/AsmState.h"
#include "mlir/IR/Attributes.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/IR/Types.h"
#include "mlir/IR/ValueRange.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Support/LLVM.h"
#include "mlir/Support/TypeID.h"
#include "mlir/Transforms/DialectConversion.h"
#include "llvm/ADT/PointerUnion.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/iterator_range.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/FormatVariadic.h"
#include "llvm/Support/LogicalResult.h"
#include "llvm/Support/raw_ostream.h"
#include <cstdint>
#include <iostream>
#include <optional>
#include <unordered_map>

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

  static std::optional<mlir::Type> convertClock(seq::ClockType t) {
    return rtlil::MValueType::get(
        t.getContext(),
        mlir::IntegerAttr::get(mlir::IntegerType::get(t.getContext(), 32), 1));
  }

  static Value materializeInt(mlir::OpBuilder &builder, rtlil::MValueType t,
                              mlir::ValueRange vals, Location pos) {
    bool isInput = vals.empty();
    if (vals.size() > 1) {
      return {};
    }
    mlir::StringAttr name = builder.getStringAttr("undefined");
    if (!isInput) {
      auto opname = vals[0].getDefiningOp()->getName().getStringRef();
      name = builder.getStringAttr(llvm::formatv("${0}_wire", opname));
    }
    return builder.create<rtlil::WireOp>(
        pos, t, name, cast<mlir::IntegerAttr>(t.getWidth()).getInt(), 0, 0,
        isInput, 0, 0, 0);
  }

public:
  RTLILTypeConverter() : mlir::TypeConverter() {
    addConversion(convertInt);
    addConversion(convertInteger);
    addConversion(convertClock);
    addTargetMaterialization(materializeInt);
  }

  void convertSignature() {}
};

namespace {

template <typename T>
struct ConversionPatternBase : public OpConversionPattern<T> {
private:
  using Super = OpConversionPattern<T>;

protected:
  std::unordered_map<int, std::pair<int, mlir::StringAttr>> &portMap;

public:
  ConversionPatternBase(
      const TypeConverter &typeConverter,
      std::unordered_map<int, std::pair<int, mlir::StringAttr>> &portMap,
      MLIRContext *context)
      : Super(typeConverter, context), portMap(portMap) {}
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
  mlir::StringAttr makeGlobal(mlir::ConversionPatternRewriter &r, S s) const {
    auto res = llvm::formatv("\\{0}", s);
    return r.getStringAttr(res);
  }
  template <typename S>
  mlir::StringAttr makeLocal(mlir::ConversionPatternRewriter &r, S s) const {
    auto res = llvm::formatv("${0}", s);
    return r.getStringAttr(res);
  }
  mlir::StringAttr asOperand(mlir::ConversionPatternRewriter &r,
                             Value v) const {
    std::string result;
    llvm::raw_string_ostream os(result);
    v.printAsOperand(os, {});
    return r.getStringAttr(result);
  }
};

struct CompRegOpResetConversion : ConversionPatternBase<seq::CompRegOp> {
  using ConversionPatternBase<seq::CompRegOp>::ConversionPatternBase;

  LogicalResult
  matchAndRewrite(seq::CompRegOp op, OpAdaptor adaptor,
                  mlir::ConversionPatternRewriter &rewriter) const override {
    if (!op.getReset() || op.getInitialValue()) {
      return failure();
    }
    auto resultType = getTypeConverter()->convertType(op.getData().getType());
    rtlil::WireOp resultWire =
        getTypeConverter()
            ->materializeTargetConversion(rewriter, op->getLoc(), resultType,
                                          op.getData())
            .getDefiningOp<rtlil::WireOp>();
    auto name = op.getInnerSym()
                    ? makeGlobal(rewriter, op.getInnerSymAttrName())
                    : makeLocal(rewriter, op.getNameAttr());
    rewriter.modifyOpInPlace(resultWire, [&] {
      resultWire.setNameAttr(asOperand(rewriter, op->getResult(0)));
    });
    std::vector<Value> connections({adaptor.getClk(), adaptor.getInput(),
                                    adaptor.getReset(), adaptor.getResetValue(),
                                    resultWire});
    rewriter.create<rtlil::ALDFFOp>(op->getLoc(), name, std::move(connections),
                                    resultWire.getWidth());
    rewriter.replaceOp(op, resultWire);
    return success();
  }
};

struct CompRegOpConversion : ConversionPatternBase<seq::CompRegOp> {
  using ConversionPatternBase<seq::CompRegOp>::ConversionPatternBase;

  LogicalResult
  matchAndRewrite(seq::CompRegOp op, OpAdaptor adaptor,
                  mlir::ConversionPatternRewriter &rewriter) const override {
    if (op.getReset() || op.getInitialValue()) {
      return failure();
    }
    auto resultType = getTypeConverter()->convertType(op.getData().getType());
    rtlil::WireOp resultWire =
        getTypeConverter()
            ->materializeTargetConversion(rewriter, op->getLoc(), resultType,
                                          op.getData())
            .getDefiningOp<rtlil::WireOp>();
    auto name = op.getInnerSym()
                    ? makeGlobal(rewriter, op.getInnerSymAttrName())
                    : makeLocal(rewriter, op.getNameAttr());
    rewriter.modifyOpInPlace(resultWire, [&] {
      resultWire.setNameAttr(asOperand(rewriter, op->getResult(0)));
    });
    std::vector<Value> connections(
        {adaptor.getClk(), adaptor.getInput(), resultWire});
    rewriter.create<rtlil::DFFOp>(op.getLoc(), name, std::move(connections),
                                  resultWire.getWidth());
    rewriter.replaceOp(op, resultWire);
    return success();
  }
};

struct CombAndOpConversion : ConversionPatternBase<AndOp> {
  using ConversionPatternBase<AndOp>::ConversionPatternBase;

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
    mlir::Attribute portarr[3] = {getStr("\\A"), getStr("\\B"), getStr("\\Y")};
    mlir::Attribute paramarr[] = {
        getParameter("\\A_SIGNED", 0),
        getParameter("\\A_WIDTH", cast<mlir::IntegerAttr>(
                                      cast<rtlil::MValueType>(
                                          adaptor.getInputs()[0].getType())
                                          .getWidth())
                                      .getInt()),
        getParameter("\\B_SIGNED", 0),
        getParameter("\\B_WIDTH", cast<mlir::IntegerAttr>(
                                      cast<rtlil::MValueType>(
                                          adaptor.getInputs()[1].getType())
                                          .getWidth())
                                      .getInt()),
        getParameter(
            "\\Y_WIDTH",
            cast<mlir::IntegerAttr>(
                cast<rtlil::MValueType>(resultWire.getType()).getWidth())
                .getInt())};
    mlir::ArrayAttr portnames = rewriter.getArrayAttr(portarr);
    mlir::ArrayAttr params = rewriter.getArrayAttr(paramarr);
    rewriter.create<rtlil::CellOp>(
        op.getLoc(), makeLocal(rewriter, asOperand(rewriter, op->getResult(0))),
        "$and", std::move(connections), portnames, params);
    rewriter.replaceOp(op, resultWire);
    return success();
  }
}; // namespace

struct ModuleConversion : ConversionPatternBase<hw::HWModuleOp> {
  using ConversionPatternBase<hw::HWModuleOp>::ConversionPatternBase;
  LogicalResult
  matchAndRewrite(hw::HWModuleOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    if (!op.getBody().hasOneBlock()) {
      return failure();
    }
    auto result = rewriter.create<mlir::ModuleOp>(
        op.getLoc(), makeGlobal(rewriter, op.getSymName()));
    mlir::TypeConverter::SignatureConversion converter(op.getNumInputPorts());
    for (size_t input = 0; input < op.getNumInputPorts(); input++) {
      rewriter.setInsertionPoint(result.getBody(), result.getBody()->begin());
      Value replacement = getTypeConverter()->materializeTargetConversion(
          rewriter, op->getLoc(),
          getTypeConverter()->convertType(op.getInputTypes()[input]), {});
      auto wire = replacement.getDefiningOp<rtlil::WireOp>();
      rewriter.modifyOpInPlace(wire, [&]() {
        wire.setPortId(op.getPortIdForInputId(input));
        wire.setName(makeGlobal(rewriter,
                                op.getPortName(op.getPortIdForInputId(input))));
      });
      converter.remapInput(input, replacement);
    }
    std::optional<hw::OutputOp> foundOp = std::nullopt;
    for (auto it = op.getBodyBlock()->rbegin(); it != op.getBodyBlock()->rend();
         ++it) {
      auto outputOp = llvm::dyn_cast_or_null<hw::OutputOp>(*it);
      if (outputOp) {
        foundOp = outputOp;
      }
    }
    if (foundOp) {
      for (size_t output = 0; output < op.getNumOutputPorts(); output++) {
        portMap.insert(
            {output, std::pair(op.getPortIdForOutputId(output),
                               rewriter.getStringAttr(op.getPortName(
                                   op.getPortIdForOutputId(output))))});
      }
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

struct OutputConversion : ConversionPatternBase<hw::OutputOp> {
  using ConversionPatternBase<hw::OutputOp>::ConversionPatternBase;
  LogicalResult
  matchAndRewrite(hw::OutputOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto outputs = adaptor.getOutputs();
    int i = 0;
    for (auto wire : outputs) {
      auto op = wire.getDefiningOp<rtlil::WireOp>();
      rewriter.modifyOpInPlace(op, [&] {
        op.setPortOutput(true);
        op.setPortId(portMap[i].first);
        op.setName(makeGlobal(rewriter, portMap[i++].second));
      });
    }
    rewriter.eraseOp(op);
    return success();
  }
};

struct InstanceConversion : ConversionPatternBase<hw::InstanceOp> {
  using ConversionPatternBase<hw::InstanceOp>::ConversionPatternBase;
  LogicalResult
  matchAndRewrite(hw::InstanceOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    llvm::SmallVector<mlir::Attribute> ports;
    for (auto &in : op.getArgNames()) {
      ports.emplace_back(makeGlobal(rewriter, cast<mlir::StringAttr>(in)));
    }
    for (auto &out : op.getResultNames()) {
      ports.emplace_back(makeGlobal(rewriter, cast<mlir::StringAttr>(out)));
    }
    llvm::SmallVector<Value> resultWires(adaptor.getInputs());
    for (auto res : op->getResults()) {
      auto type = getTypeConverter()->convertType(res.getType());
      auto wire = getTypeConverter()->materializeTargetConversion(
          rewriter, res.getLoc(), type, res);
      resultWires.emplace_back(wire);
    }
    rewriter.create<rtlil::IntanceOp>(
        op->getLoc(), makeGlobal(rewriter, op.getInstanceNameAttr()),
        makeGlobal(rewriter, op.getModuleName()), resultWires,
        rewriter.getArrayAttr(ports), rewriter.getArrayAttr({}));
    resultWires.erase(resultWires.begin(),
                      resultWires.begin() + op.getNumInputPorts());
    rewriter.replaceOp(op, mlir::ValueRange(resultWires));
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

template <typename M>
static void populateCombToRTLILConversionPatterns(TypeConverter &converter,
                                                  M &portMap,
                                                  RewritePatternSet &patterns) {
  patterns
      .add<ModuleConversion, OutputConversion, CombAndOpConversion,
           InstanceConversion, CompRegOpResetConversion, CompRegOpConversion>(
          converter, portMap, patterns.getContext());
}

void ConvertCombToRTLILPass::runOnOperation() {
  ConversionTarget target(getContext());
  mlir::ConversionConfig config;
  target.addLegalDialect<rtlil::RTLILDialect>();
  target.addIllegalDialect<comb::CombDialect>();
  target.addIllegalDialect<seq::SeqDialect>();
  target.addLegalOp<mlir::ModuleOp>();
  std::unordered_map<int, std::pair<int, mlir::StringAttr>> portMap;

  RewritePatternSet patterns(&getContext());
  RTLILTypeConverter converter;
  populateCombToRTLILConversionPatterns(converter, portMap, patterns);
  if (failed(mlir::applyPartialConversion(getOperation(), target,
                                          std::move(patterns)))) {
    return signalPassFailure();
  }
}
