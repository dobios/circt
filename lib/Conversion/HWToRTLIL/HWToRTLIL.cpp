//===- HWToRTLIL.cpp ----------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "circt/Conversion/HWToRTLIL.h"
#include "circt/Conversion/RTLILCommon.h"
#include "circt/Dialect/Comb/CombDialect.h"
#include "circt/Dialect/Comb/CombOps.h"
#include "circt/Dialect/HW/HWOps.h"
#include "circt/Dialect/HW/HWTypes.h"
#include "circt/Dialect/RTLIL/RTLIL.h"
#include "circt/Dialect/Seq/SeqDialect.h"
#include "circt/Dialect/Seq/SeqOps.h"
#include "circt/Support/LLVM.h"
#include "mlir/Analysis/TopologicalSortUtils.h"
#include "mlir/IR/AsmState.h"
#include "mlir/IR/Attributes.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/IR/Types.h"
#include "mlir/IR/ValueRange.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Pass/PassManager.h"
#include "mlir/Support/LLVM.h"
#include "mlir/Support/TypeID.h"
#include "mlir/Transforms/DialectConversion.h"
#include "llvm/ADT/PointerUnion.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/LogicalResult.h"
#include <cstdint>
#include <memory>
#include <optional>
#include <type_traits>
#include <unordered_map>

namespace circt {
#define GEN_PASS_DEF_CONVERTHWTORTLIL
#include "circt/Conversion/Passes.h.inc"
} // namespace circt

using namespace circt;
using namespace comb;

// TODO proper scoping mechanism for symbols --> global rtlil names
// likely symbol table walk with prefixes

//===----------------------------------------------------------------------===//
// Conversion patterns
//===----------------------------------------------------------------------===//

namespace {

using rtlil::ConversionPatternBase;
struct CompRegOpResetConversion : ConversionPatternBase<seq::CompRegOp> {
  using ConversionPatternBase<seq::CompRegOp>::ConversionPatternBase;

  LogicalResult
  matchAndRewrite(seq::CompRegOp op, OpAdaptor adaptor,
                  mlir::ConversionPatternRewriter &rewriter) const override {
    if (!op.getReset() || op.getInitialValue()) {
      return failure();
    }
    rtlil::WireOp resultWire =
        genLocalWire(op->getLoc(), op.getData(), rewriter);
    auto name = op.getInnerSym()
                    ? makeGlobal(rewriter, op.getInnerSymAttr().getSymName(),
                                 op->getLoc())
                    : genLocal(rewriter);
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
    rtlil::WireOp resultWire =
        genLocalWire(op->getLoc(), op.getData(), rewriter);
    auto name = op.getInnerSym()
                    ? makeGlobal(rewriter, op.getInnerSymAttr().getSymName(),
                                 op->getLoc()) // this should be prefixed
                                               // by the module probably
                    : genLocal(rewriter);
    std::vector<Value> connections(
        {adaptor.getClk(), adaptor.getInput(), resultWire});
    rewriter.create<rtlil::DFFOp>(op.getLoc(), name, std::move(connections),
                                  resultWire.getWidth());
    rewriter.replaceOp(op, resultWire);
    return success();
  }
};

struct FirRegOpConversion : ConversionPatternBase<seq::FirRegOp> {
  using ConversionPatternBase<seq::FirRegOp>::ConversionPatternBase;

  LogicalResult
  matchAndRewrite(seq::FirRegOp op, OpAdaptor adaptor,
                  mlir::ConversionPatternRewriter &rewriter) const override {
    if (op.getReset() || op.getPreset()) {
      return failure();
    }
    rtlil::WireOp resultWire =
        genLocalWire(op->getLoc(), op.getData(), rewriter);
    auto name = op.getInnerSym()
                    ? makeGlobal(rewriter, op.getInnerSymAttr().getSymName(),
                                 op->getLoc()) // this should be prefixed
                                               // by the module probably
                    : genLocal(rewriter);
    std::vector<Value> connections(
        {adaptor.getClk(), adaptor.getNext(), resultWire});
    rewriter.create<rtlil::DFFOp>(op.getLoc(), name, std::move(connections),
                                  resultWire.getWidth());
    rewriter.replaceOp(op, resultWire);
    return success();
  }
};

struct FirRegOpResetConversion : ConversionPatternBase<seq::FirRegOp> {
  using ConversionPatternBase<seq::FirRegOp>::ConversionPatternBase;

  LogicalResult
  matchAndRewrite(seq::FirRegOp op, OpAdaptor adaptor,
                  mlir::ConversionPatternRewriter &rewriter) const override {
    if (!op.getReset() || op.getPreset()) {
      return failure();
    }
    rtlil::WireOp resultWire =
        genLocalWire(op->getLoc(), op.getData(), rewriter);
    auto name = op.getInnerSym()
                    ? makeGlobal(rewriter, op.getInnerSymAttr().getSymName(),
                                 op->getLoc())
                    : genLocal(rewriter);
    std::vector<Value> connections({adaptor.getClk(), adaptor.getNext(),
                                    adaptor.getReset(), adaptor.getResetValue(),
                                    resultWire});
    if (op.getIsAsync()) {
      rewriter.create<rtlil::ALDFFOp>(
          op->getLoc(), name, std::move(connections), resultWire.getWidth());
    } else {
      rtlil::WireOp bufferedResetWire =
          genLocalWire(op->getLoc(), op.getReset(), rewriter);
      {
        auto syncedResetWire =
            genLocalWire(op->getLoc(), op.getReset(), rewriter);
        if (!syncedResetWire)
          return failure();
        Value connections[3] = {adaptor.getClk(), adaptor.getReset(),
                                syncedResetWire};
        rewriter.create<rtlil::DFFOp>(op.getLoc(), genLocal(rewriter),
                                      connections, syncedResetWire.getWidth());
        Value connections2[3] = {syncedResetWire, adaptor.getReset(),
                                 bufferedResetWire};
        rewriter.create<rtlil::AndOp>(op->getLoc(), genLocal(rewriter),
                                      connections2, 1, false);
      }
      std::vector<Value> connections({adaptor.getClk(), adaptor.getNext(),
                                      bufferedResetWire,
                                      adaptor.getResetValue(), resultWire});
      rewriter.create<rtlil::ALDFFOp>(
          op->getLoc(), name, std::move(connections), resultWire.getWidth());
    }
    rewriter.replaceOp(op, resultWire);
    return success();
  }
};

template <typename BinOp, typename ResultOp, typename = void>
struct BinOpConversion;

template <typename BinOp, typename ResultOp>
struct BinOpConversion<BinOp, ResultOp,
                       std::enable_if_t<std::is_member_function_pointer_v<
                           decltype(&BinOp::getInputs)>>>
    : ConversionPatternBase<BinOp> {
  using Super = ConversionPatternBase<BinOp>;
  using Super::ConversionPatternBase;
  using typename Super::OpAdaptor;

  LogicalResult matchAndRewrite(BinOp op, OpAdaptor adaptor,
                                ConversionPatternRewriter &r) const override {
    if (op.getNumOperands() != 2)
      return failure();

    auto resultWire = Super::genLocalWire(op->getLoc(), op->getResult(0), r);
    std::vector<Value> connections(
        {adaptor.getInputs()[0], adaptor.getInputs()[1], resultWire});
    r.create<ResultOp>(op->getLoc(), Super::genLocal(r), std::move(connections),
                       op.getInputs()[0].getType().getIntOrFloatBitWidth(),
                       false);
    r.replaceOp(op, resultWire);
    return success();
  }
};

template <typename BinOp, typename ResultOp>
struct BinOpConversion<BinOp, ResultOp,
                       std::enable_if_t<std::is_member_function_pointer_v<
                           decltype(&BinOp::getLhs)>>>
    : ConversionPatternBase<BinOp> {
  using Super = ConversionPatternBase<BinOp>;
  using Super::ConversionPatternBase;
  using typename Super::OpAdaptor;

  LogicalResult matchAndRewrite(BinOp op, OpAdaptor adaptor,
                                ConversionPatternRewriter &r) const override {
    if (op.getNumOperands() != 2)
      return failure();

    auto resultWire = Super::genLocalWire(op->getLoc(), op->getResult(0), r);
    std::vector<Value> connections(
        {adaptor.getLhs(), adaptor.getRhs(), resultWire});
    r.create<ResultOp>(op->getLoc(), Super::genLocal(r), std::move(connections),
                       op.getLhs().getType().getIntOrFloatBitWidth(), false);
    r.replaceOp(op, resultWire);
    return success();
  }
};

struct MuxOpConversion : ConversionPatternBase<MuxOp> {
  using ConversionPatternBase<MuxOp>::ConversionPatternBase;

  LogicalResult matchAndRewrite(MuxOp op, OpAdaptor adaptor,
                                ConversionPatternRewriter &r) const override {
    if (op.getTrueValue().getType() != op.getFalseValue().getType()) {
      return failure();
    }

    auto resultWire = genLocalWire(op->getLoc(), op->getResult(0), r);
    Value connections[4] = {adaptor.getFalseValue(), adaptor.getTrueValue(),
                            adaptor.getCond(), resultWire};

    r.create<rtlil::MuxOp>(op->getLoc(), genLocal(r), connections,
                           op.getTrueValue().getType().getIntOrFloatBitWidth());
    r.replaceOp(op, resultWire);

    return success();
  }
};

struct ConstantConversion : ConversionPatternBase<hw::ConstantOp> {
  using ConversionPatternBase<hw::ConstantOp>::ConversionPatternBase;

  LogicalResult
  matchAndRewrite(hw::ConstantOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto outType = getTypeConverter()->convertType<rtlil::MValueType>(
        op->getResultTypes()[0]);
    mlir::IntegerAttr value = adaptor.getValueAttr();
    auto width = value.getType().getIntOrFloatBitWidth();
    if (width > 64) {
      return failure();
    }
    uint64_t intVal = value.getInt();

    llvm::SmallVector<Attribute> v;

    for (unsigned int idx = 0; idx < width; idx++) {
      if (intVal & (1ull << idx)) {
        v.emplace_back(
            rtlil::StateEnumAttr::get(getContext(), rtlil::StateEnum::S1));
      } else {
        v.emplace_back(
            rtlil::StateEnumAttr::get(getContext(), rtlil::StateEnum::S0));
      }
    }

    rewriter.replaceOpWithNewOp<rtlil::ConstOp>(op, outType,
                                                rewriter.getArrayAttr(v));
    return success();
  }
};

struct ModuleConversion : ConversionPatternBase<hw::HWModuleOp> {
  using ConversionPatternBase<hw::HWModuleOp>::ConversionPatternBase;
  LogicalResult
  matchAndRewrite(hw::HWModuleOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    if (!op.getBody().hasOneBlock()) {
      return failure();
    }
    {
      auto guard = rtlilContext.lock();
      rtlilContext.portMap.clear();
    }
    auto result = rewriter.create<mlir::ModuleOp>(
        op.getLoc(), makeGlobal(rewriter, op.getSymName(), op->getLoc()));
    mlir::TypeConverter::SignatureConversion converter(op.getNumInputPorts());
    for (size_t input = 0; input < op.getNumInputPorts(); input++) {
      rewriter.setInsertionPoint(result.getBody(), result.getBody()->begin());
      Value replacement = getTypeConverter()->materializeTargetConversion(
          rewriter, op->getLoc(),
          getTypeConverter()->convertType(op.getInputTypes()[input]), {});
      auto wire = replacement.getDefiningOp<rtlil::WireOp>();
      rewriter.modifyOpInPlace(wire, [&]() {
        wire.setPortId(op.getPortIdForInputId(input) + 1);
        wire.setName(makeGlobal(rewriter,
                                op.getPortName(op.getPortIdForInputId(input)),
                                op->getLoc()));
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
        auto guard = rtlilContext.lock();
        auto [_, inserted] = rtlilContext.portMap.insert(
            {output, std::pair(op.getPortIdForOutputId(output),
                               makeGlobal(rewriter,
                                          op.getPortName(
                                              op.getPortIdForOutputId(output)),
                                          op->getLoc()))});
        if (!inserted)
          return failure();
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

struct ModuleSorter : ConversionPatternBase<mlir::ModuleOp> {
  using ConversionPatternBase<mlir::ModuleOp>::ConversionPatternBase;
  LogicalResult
  matchAndRewrite(mlir::ModuleOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    rewriter.modifyOpInPlace(op,
                             [&] { mlir::sortTopologically(op.getBody()); });
    return success();
  }
};

struct OutputConversion : ConversionPatternBase<hw::OutputOp> {
  using ConversionPatternBase<hw::OutputOp>::ConversionPatternBase;
  LogicalResult
  matchAndRewrite(hw::OutputOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto outputs = adaptor.getOutputs();
    int i = 0;
    for (auto wire : outputs) {
      auto op = wire.getDefiningOp<rtlil::WireOp>();
      auto guard = rtlilContext.lock();
      rewriter.modifyOpInPlace(op, [&] {
        op.setPortOutput(true);
        op.setPortId(rtlilContext.portMap[i].first + 1);
        op.setName(rtlilContext.portMap[i++].second);
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
    auto definingOp = rtlil::lookupSymbolWalkTables<hw::HWModuleOp>(
        op, op.getModuleNameAttr());
    if (!definingOp)
      return failure();
    for (auto &in : op.getArgNames()) {
      ports.emplace_back(makeGlobal(
          rewriter, cast<mlir::StringAttr>(in).strref(),
          definingOp->getLoc()) // todo find reference in symbol table
      );
    }
    for (auto &out : op.getResultNames()) {
      ports.emplace_back(makeGlobal(
          rewriter, cast<mlir::StringAttr>(out).strref(),
          definingOp->getLoc()) // todo find reference in symbol table
      );
    }
    llvm::SmallVector<Value> resultWires(adaptor.getInputs());
    for (auto res : op->getResults()) {
      auto type = getTypeConverter()->convertType(res.getType());
      auto wire = getTypeConverter()->materializeTargetConversion(
          rewriter, res.getLoc(), type, res);
      resultWires.emplace_back(wire);
    }

    rewriter.create<rtlil::IntanceOp>(
        op->getLoc(),
        makeGlobal(rewriter, op.getInstanceNameAttr(), op->getLoc()),
        makeGlobal(rewriter, op.getModuleName(), definingOp->getLoc()),
        resultWires, rewriter.getArrayAttr(ports), rewriter.getArrayAttr({}));
    resultWires.erase(resultWires.begin(),
                      resultWires.begin() + op.getNumInputPorts());
    rewriter.replaceOp(op, mlir::ValueRange(resultWires));
    return success();
  }
};

struct ICMPConversion : ConversionPatternBase<comb::ICmpOp> {
  using ConversionPatternBase<comb::ICmpOp>::ConversionPatternBase;

  LogicalResult
  matchAndRewrite(comb::ICmpOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto pred = adaptor.getPredicate();
    if (static_cast<int>(pred) > 10 || !adaptor.getTwoState()) {
      return failure(); // currently not supported
    }
    auto resultWire = genLocalWire(op->getLoc(), op.getResult(), rewriter);
    mlir::Value connections[3] = {adaptor.getLhs(), adaptor.getRhs(),
                                  resultWire};
    switch (pred) {
    case ICmpPredicate::eq:
      rewriter.create<rtlil::EQOp>(
          op->getLoc(), genLocal(rewriter), connections,
          op.getLhs().getType().getIntOrFloatBitWidth(), false);
      break;
    case ICmpPredicate::ne:
      rewriter.create<rtlil::NEOp>(
          op->getLoc(), genLocal(rewriter), connections,
          op.getLhs().getType().getIntOrFloatBitWidth(), false);
      break;
    case ICmpPredicate::ugt:
    case ICmpPredicate::sgt:
      rewriter.create<rtlil::GTOp>(
          op->getLoc(), genLocal(rewriter), connections,
          op.getLhs().getType().getIntOrFloatBitWidth(),
          pred == ICmpPredicate::sgt);
      break;
    case ICmpPredicate::ult:
    case ICmpPredicate::slt:
      rewriter.create<rtlil::LTOp>(
          op->getLoc(), genLocal(rewriter), connections,
          op.getLhs().getType().getIntOrFloatBitWidth(),
          pred == ICmpPredicate::slt);
      break;
    case ICmpPredicate::ule:
    case ICmpPredicate::sle:
      rewriter.create<rtlil::LEOp>(
          op->getLoc(), genLocal(rewriter), connections,
          op.getLhs().getType().getIntOrFloatBitWidth(),
          pred == ICmpPredicate::sle);
      break;
    case ICmpPredicate::uge:
    case ICmpPredicate::sge:
      rewriter.create<rtlil::GEOp>(
          op->getLoc(), genLocal(rewriter), connections,
          op.getLhs().getType().getIntOrFloatBitWidth(),
          pred == ICmpPredicate::sge);
      break;
    default:
      return failure();
      break;
    }
    rewriter.replaceOp(op, resultWire);
    return success();
  }
};

} // namespace
//===----------------------------------------------------------------------===//
// Convert Comb to SMT pass
//===----------------------------------------------------------------------===//

namespace {
struct ConvertHWToRTLILPass
    : public circt::impl::ConvertHWToRTLILBase<ConvertHWToRTLILPass> {
  void runOnOperation() override;
};

struct SortModulePass
    : public mlir::PassWrapper<SortModulePass,
                               mlir::OperationPass<mlir::ModuleOp>> {
  void runOnOperation() override {
    auto op = getOperation();
    mlir::sortTopologically(op.getBody());
  }
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(SortModulePass);
};
} // namespace

static void populateHWToRTLILConversionPatterns(
    TypeConverter &converter, rtlil::ConversionPatternContext &rtlilContext,
    RewritePatternSet &patterns) {
  patterns.add<
      ModuleConversion, OutputConversion, BinOpConversion<AndOp, rtlil::AndOp>,
      BinOpConversion<SubOp, rtlil::SubOp>, BinOpConversion<OrOp, rtlil::OrOp>,
      MuxOpConversion, InstanceConversion, CompRegOpResetConversion,
      CompRegOpConversion, FirRegOpResetConversion, FirRegOpConversion,
      ConstantConversion, ICMPConversion>(converter, rtlilContext,
                                          patterns.getContext());
}

void ConvertHWToRTLILPass::runOnOperation() {
  ConversionTarget target(getContext());
  mlir::ConversionConfig config;
  target.addLegalDialect<rtlil::RTLILDialect>();
  target.addIllegalDialect<comb::CombDialect>();
  target.addIllegalDialect<seq::SeqDialect>();
  target.addLegalOp<mlir::ModuleOp>();
  rtlil::ConversionPatternContext context;

  RewritePatternSet patterns(&getContext());
  rtlil::RTLILTypeConverter converter;
  populateHWToRTLILConversionPatterns(converter, context, patterns);
  if (failed(mlir::applyPartialConversion(getOperation(), target,
                                          std::move(patterns)))) {
    return signalPassFailure();
  }
  RewritePatternSet sortPatterns(&getContext());
  sortPatterns.add<ModuleSorter>(converter, context, sortPatterns.getContext());

  ConversionTarget sortTarget(getContext());
  mlir::OpPassManager dynamicPm("builtin.module");
  dynamicPm.addNestedPass<mlir::ModuleOp>(std::make_unique<SortModulePass>());
  if (failed(runPipeline(dynamicPm, getOperation()))) {
    signalPassFailure();
  }
}
