//===- LTLToCore.cpp -----------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Converts LTL and Verif operations to Core operations
//
//===----------------------------------------------------------------------===//

#include "circt/Conversion/LTLToCore.h"
#include "../PassDetail.h"
#include "circt/Conversion/HWToSV.h"
#include "circt/Dialect/Comb/CombOps.h"
#include "circt/Dialect/HW/HWOps.h"
#include "circt/Dialect/LTL/LTLDialect.h"
#include "circt/Dialect/LTL/LTLOps.h"
#include "circt/Dialect/SV/SVDialect.h"
#include "circt/Dialect/SV/SVOps.h"
#include "circt/Dialect/Seq/SeqOps.h"
#include "circt/Dialect/Verif/VerifOps.h"
#include "circt/Support/BackedgeBuilder.h"
#include "circt/Support/Namespace.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/Transforms/DialectConversion.h"
#include "llvm/Support/MathExtras.h"

using namespace mlir;
using namespace circt;
using namespace hw;

static sv::EventControl ltlToSVEventControl(ltl::ClockEdge ce) {
  switch (ce) {
  case ltl::ClockEdge::Pos:
    return sv::EventControl::AtPosEdge;
  case ltl::ClockEdge::Neg:
    return sv::EventControl::AtNegEdge;
  case ltl::ClockEdge::Both:
    return sv::EventControl::AtEdge;
  }
  llvm_unreachable("Unknown event control kind");
}

//===----------------------------------------------------------------------===//
// Conversion patterns
//===----------------------------------------------------------------------===//

namespace {

// Custom pattern matchers

// Matches and records a boolean attribute
struct I1ValueMatcher {
  Value *what;
  I1ValueMatcher(Value *what) : what(what) {}
  bool match(Value op) const {
    if (!op.getType().isSignlessInteger(1))
      return false;
    *what = op;
    return true;
  }
};

static inline I1ValueMatcher m_Bool(Value *const val) {
  return I1ValueMatcher(val);
}

// Matches and records an arbitrary op
template <typename OpType, typename... OperandMatchers>
struct BindingRecursivePatternMatcher
    : mlir::detail::RecursivePatternMatcher<OpType, OperandMatchers...> {

  using BaseMatcher =
      mlir::detail::RecursivePatternMatcher<OpType, OperandMatchers...>;
  BindingRecursivePatternMatcher(OpType *_op, OperandMatchers... matchers)
      : BaseMatcher(matchers...), opBind(_op) {}

  bool match(Operation *op) {
    if (BaseMatcher::match(op)) {
      *opBind = llvm::cast<OpType>(op);
      return true;
    }
    return false;
  }

  OpType *opBind;
};

template <typename OpType, typename... Matchers>
static inline auto m_OpWithBind(OpType *op, Matchers... matchers) {
  return BindingRecursivePatternMatcher<OpType, Matchers...>(op, matchers...);
}

struct HasBeenResetOpConversion : OpConversionPattern<verif::HasBeenResetOp> {
  using OpConversionPattern<verif::HasBeenResetOp>::OpConversionPattern;

  // HasBeenReset generates a 1 bit register that is set to one once the reset
  // has been raised and lowered at at least once.
  LogicalResult
  matchAndRewrite(verif::HasBeenResetOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto i1 = rewriter.getI1Type();
    // Generate the constant used to set the register value
    Value constZero = rewriter.create<hw::ConstantOp>(op.getLoc(), i1, 0);

    // Generate the constant used to enegate the
    Value constOne = rewriter.create<hw::ConstantOp>(op.getLoc(), i1, 1);

    // Create a backedge for the register to be used in the OrOp
    circt::BackedgeBuilder bb(rewriter, op.getLoc());
    circt::Backedge reg = bb.get(rewriter.getI1Type());

    // Generate an or between the reset and the register's value to store
    // whether or not the reset has been active at least once
    Value orReset =
        rewriter.create<comb::OrOp>(op.getLoc(), adaptor.getReset(), reg);

    // This register should not be reset, so we give it dummy reset and resetval
    // operands to fit the build signature
    Value reset, resetval;

    // Finally generate the register to set the backedge
    reg.setValue(rewriter.create<seq::CompRegOp>(
        op.getLoc(), orReset,
        rewriter.createOrFold<seq::ToClockOp>(op.getLoc(), adaptor.getClock()),
        reset, resetval, llvm::StringRef("hbr"), constZero));

    // We also need to consider the case where we are currently in a reset cycle
    // in which case our hbr register should be down-
    // Practically this means converting it to (and hbr (not reset))
    Value notReset =
        rewriter.create<comb::XorOp>(op.getLoc(), adaptor.getReset(), constOne);
    rewriter.replaceOpWithNewOp<comb::AndOp>(op, reg, notReset);

    return success();
  }
};

struct AssertOpConversionPattern : OpConversionPattern<verif::AssertOp> {
  using OpConversionPattern<verif::AssertOp>::OpConversionPattern;

  Value visit(ltl::DisableOp op, ConversionPatternRewriter &rewriter,
              Value operand = nullptr) const {
    // Replace the ltl::DisableOp with an OR op as it represents a disabling
    // implication: (implies (not condition) input) is equivalent to
    // (or (not (not condition)) input) which becomes (or condition input)
    return rewriter.replaceOpWithNewOp<comb::OrOp>(
        op, op.getCondition(), operand ? operand : op.getInput());
  }

  // Creates and returns a logical implication:
  // a -> b which is encoded as !a || b
  // The Value for the OrOp will be returned
  Value makeImplication(Location loc, Value antecedent, Value consequent,
                        ConversionPatternRewriter &rewriter) const {
    Value constOne =
        rewriter.create<hw::ConstantOp>(loc, rewriter.getI1Type(), 1);
    Value nA = rewriter.create<comb::XorOp>(loc, antecedent, constOne);
    return rewriter.create<comb::OrOp>(loc, nA, consequent);
  }

  // NOI case: Generate a register delaying our antecedent
  // for each cycle in delayN, as well as a register to count the
  // delay, e.g. a ##n true |-> b would have the following assertion:
  // assert(delay < n || (!a_n || b) || reset)
  bool makeNonOverlappingImplication(Value antecedent, Value consequent,
                                     ltl::DelayOp delayN, ltl::ClockOp ltlclock,
                                     Value disableCond,
                                     ConversionPatternRewriter &rewriter,
                                     Value &res) const {

    // Start by recovering the number of registers we need to generate
    uint64_t delayCycles = delayN.getDelay();

    // The width of our delay register can simply be log2(delayCycles) +
    // 1 as we can saturate it once it's reached delayCycles
    uint64_t delayRegW = llvm::Log2_64(delayCycles) + 1;
    auto idrw = IntegerType::get(getContext(), delayRegW);

    // Build out the delay register: delay' = delay + 1; reset(delay, 0)
    // Generate the constant used to enegate the
    Value constZero = rewriter.create<hw::ConstantOp>(delayN.getLoc(), idrw, 0);

    // Create a constant to be used in the delay next statement
    Value constOneW = rewriter.create<hw::ConstantOp>(delayN.getLoc(), idrw, 1);

    // Create a backedge for the delay register
    circt::BackedgeBuilder bb(rewriter, delayN.getLoc());
    circt::Backedge delayReg = bb.get(idrw);

    // Increment the delay register by 1
    Value delayInc =
        rewriter.create<comb::AddOp>(delayN.getLoc(), delayReg, constOneW);

    // Saturate the register if it reaches the delay, i.e. delay' = (delay
    // == delayCycles) ? delayCycles : delay + 1
    Value delayMax =
        rewriter.create<hw::ConstantOp>(delayN.getLoc(), idrw, delayCycles);
    Value delayEqMax = rewriter.create<comb::ICmpOp>(
        delayN.getLoc(),
        comb::ICmpPredicateAttr::get(getContext(), comb::ICmpPredicate::eq),
        delayReg, delayMax, mlir::UnitAttr::get(getContext()));
    Value delayMux = rewriter.create<comb::MuxOp>(delayN.getLoc(), delayEqMax,
                                                  delayMax, delayInc);

    // Extract the actual clock
    auto clock = rewriter.createOrFold<seq::ToClockOp>(delayN.getLoc(),
                                                       ltlclock.getClock());

    // Create the actual register
    // Use the associated disable condition as the generated register's reset
    delayReg.setValue(rewriter.create<seq::CompRegOp>(
        delayN.getLoc(), delayMux, clock, disableCond, constZero,
        llvm::StringRef("delay_"), constZero));

    // Previous register in the pipeline
    Value aI;

    // Generate reset values
    auto aType = antecedent.getType();
    auto itype = isa<IntegerType>(aType)
                     ? aType
                     : IntegerType::get(getContext(), hw::getBitWidth(aType));
    Value resetVal = rewriter.create<hw::ConstantOp>(delayN.getLoc(), itype, 0);

    aI = rewriter.create<seq::CompRegOp>(
        delayN.getLoc(), antecedent, clock, disableCond, resetVal,
        llvm::StringRef("antecedent_0"), resetVal);

    // Create a pipeline of delay registers
    for (size_t i = 1; i < delayCycles; ++i)
      aI = rewriter.create<seq::CompRegOp>(
          delayN.getLoc(), aI, clock, disableCond, resetVal,
          llvm::StringRef("antecedent_" + std::to_string(i)), resetVal);

    // Generate the final assertion: assert(delayReg < delayMax ||
    // (aI -> consequent) || reset)
    Value condMin = rewriter.create<comb::ICmpOp>(
        delayN.getLoc(),
        comb::ICmpPredicateAttr::get(getContext(), comb::ICmpPredicate::ult),
        delayReg, delayMax, mlir::UnitAttr::get(getContext()));
    Value constOneAi =
        rewriter.create<hw::ConstantOp>(delayN.getLoc(), aI.getType(), 1);
    Value notAi = rewriter.create<comb::XorOp>(delayN.getLoc(), aI, constOneAi);
    Value implAiConsequent =
        rewriter.create<comb::OrOp>(delayN.getLoc(), notAi, consequent);
    Value condLhs =
        rewriter.create<comb::OrOp>(delayN.getLoc(), condMin, implAiConsequent);

    // Finally create the final assertion condition
    res = rewriter.create<comb::OrOp>(delayN.getLoc(), condLhs, disableCond);
    return true;
  }

  // Special case : we want to detect the Non-overlapping implication,
  // Overlapping Implication or simply AssertProperty patterns and reject
  // everything else for now: antecedent : ltl::concatOp || immediate predicate
  // consequent : any other non-sequence op
  // We want to support a ##n true |-> b and a |-> b
  LogicalResult
  matchAndRewrite(verif::AssertOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {

    Value ltlClock, disableCond, disableInput, antecedent, consequent,
        disableVal;
    ltl::ClockOp clockOp;
    ltl::DelayOp delayOp;
    ltl::DisableOp disableOp;
    ltl::ImplicationOp implOp;
    ltl::ConcatOp concatOp;

    // Look for the NOI pattern, i.e. a ##n true |-> b
    bool matchedNOI = matchPattern(
        op.getProperty(),
        m_OpWithBind<ltl::ClockOp>(
            &clockOp,
            m_OpWithBind<ltl::DisableOp>(
                &disableOp,
                m_OpWithBind<ltl::ImplicationOp>(
                    &implOp,
                    m_OpWithBind<ltl::ConcatOp>(
                        &concatOp, m_Bool(&antecedent),
                        m_OpWithBind<ltl::DelayOp>(&delayOp, m_One())),
                    m_Bool(&consequent)),
                m_Bool(&disableCond)),
            m_Bool(&ltlClock)));

    // Make sure that we matched a legal case
    if (matchedNOI && delayOp.getLength() != 0)
      return rewriter.notifyMatchFailure(delayOp,
                                         " Delay must have a length of 0!");

    if (matchedNOI) {
      // Generate the Non-overlapping Implication
      if (!makeNonOverlappingImplication(antecedent, consequent, delayOp,
                                         clockOp, disableCond, rewriter,
                                         disableInput))
        return rewriter.notifyMatchFailure(
            implOp, "Failed to generate NOI from ltl::ImplicationOp");

    } else {
      // Look for the OI pattern, i.e. a |-> b
      bool matchedOI = matchPattern(
          op.getProperty(),
          m_OpWithBind<ltl::ClockOp>(
              &clockOp,
              m_OpWithBind<ltl::DisableOp>(
                  &disableOp,
                  m_OpWithBind<ltl::ImplicationOp>(&implOp, m_Bool(&antecedent),
                                                   m_Bool(&consequent)),
                  m_Bool(&disableCond)),
              m_Bool(&ltlClock)));

      // Generate an OI if needed
      if (matchedOI) {
        disableInput =
            makeImplication(implOp.getLoc(), antecedent, consequent, rewriter);
      } else {
        // Look for the generic AssertProperty case
        bool matched = matchPattern(
            op.getProperty(),
            m_OpWithBind<ltl::ClockOp>(
                &clockOp,
                m_OpWithBind<ltl::DisableOp>(&disableOp, m_Bool(&disableInput),
                                             m_Bool(&disableCond)),
                m_Bool(&ltlClock)));

        if (!matched)
          return rewriter.notifyMatchFailure(
              op, "AssertProperty format is invalid!");
      }
    }

    if (!disableOp)
      return rewriter.notifyMatchFailure(op, " Assertion must be disabled!");

    // Sanity check, we should have found a clock
    if (!clockOp)
      return rewriter.notifyMatchFailure(
          op, "verif.assert property is not associated to a clock! ");

    // Then visit the disable op
    disableVal = visit(disableOp, rewriter, disableInput);

    // Generate the parenting sv.always posedge clock from the ltl
    // clock, containing the generated sv.assert
    rewriter.create<sv::AlwaysOp>(
        clockOp.getLoc(), ltlToSVEventControl(clockOp.getEdge()), ltlClock,
        [&] {
          // Generate the sv assertion using the input to the
          // parenting clock
          rewriter.replaceOpWithNewOp<sv::AssertOp>(
              op, disableVal,
              sv::DeferAssertAttr::get(getContext(),
                                       sv::DeferAssert::Immediate),
              op.getLabelAttr());
        });

    // Erase Converted Ops
    rewriter.eraseOp(clockOp);
    if (implOp)
      rewriter.eraseOp(implOp);
    if (concatOp)
      rewriter.eraseOp(concatOp);
    if (delayOp)
      rewriter.eraseOp(delayOp);

    return success();
  }
};

} // namespace

//===----------------------------------------------------------------------===//
// Lower LTL To Core pass
//===----------------------------------------------------------------------===//

namespace {
struct LowerLTLToCorePass : public LowerLTLToCoreBase<LowerLTLToCorePass> {
  LowerLTLToCorePass() = default;
  void runOnOperation() override;
};
} // namespace

// Simply applies the conversion patterns defined above
void LowerLTLToCorePass::runOnOperation() {

  // Set target dialects: We don't want to see any ltl or verif that might come
  // from an AssertProperty left in the result
  ConversionTarget target(getContext());
  target.addLegalDialect<hw::HWDialect>();
  target.addLegalDialect<comb::CombDialect>();
  target.addLegalDialect<sv::SVDialect>();
  target.addLegalDialect<seq::SeqDialect>();
  target.addLegalDialect<ltl::LTLDialect>();
  target.addIllegalDialect<verif::VerifDialect>();

  // Create type converters, mostly just to convert an ltl property to a bool
  mlir::TypeConverter converter;

  // Convert the ltl property type to a built-in type
  converter.addConversion([](IntegerType type) { return type; });
  converter.addConversion([](ltl::PropertyType type) {
    return IntegerType::get(type.getContext(), 1);
  });
  converter.addConversion([](ltl::SequenceType type) {
    return IntegerType::get(type.getContext(), 1);
  });

  // Basic materializations
  converter.addTargetMaterialization(
      [&](mlir::OpBuilder &builder, mlir::Type resultType,
          mlir::ValueRange inputs,
          mlir::Location loc) -> std::optional<mlir::Value> {
        if (inputs.size() != 1)
          return std::nullopt;
        return inputs[0];
      });

  converter.addSourceMaterialization(
      [&](mlir::OpBuilder &builder, mlir::Type resultType,
          mlir::ValueRange inputs,
          mlir::Location loc) -> std::optional<mlir::Value> {
        if (inputs.size() != 1)
          return std::nullopt;
        return inputs[0];
      });

  // Create the operation rewrite patters
  RewritePatternSet patterns(&getContext());
  patterns.add<AssertOpConversionPattern, HasBeenResetOpConversion>(
      converter, patterns.getContext());

  // Apply the conversions
  if (failed(
          applyPartialConversion(getOperation(), target, std::move(patterns))))
    return signalPassFailure();
}

// Basic default constructor
std::unique_ptr<mlir::Pass> circt::createLowerLTLToCorePass() {
  return std::make_unique<LowerLTLToCorePass>();
}
