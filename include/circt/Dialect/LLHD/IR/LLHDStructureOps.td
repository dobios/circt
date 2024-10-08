//===- LLHDStructureOps.td - Process and Entity defs -------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This describes the LLHD Process, Entity and control flow MLIR ops.
//
//===----------------------------------------------------------------------===//

def ProcessOp : LLHDOp<"process", [
  NoRegionArguments,
  HasParent<"hw::HWModuleOp">
]> {
  let summary = "create a process";
  let description = [{
    A `llhd.process` represents control-flow in a timed fashion. It allows a
    procedural description of how a circuit's output signals change in
    reaction to changing input signals. It has a region with arbitrarily
    many basic blocks. The first block is the entry block and cannot be
    targeted by the terminators. It uses `llhd.wait` as a terminator to add
    timed control-flow. Immediate control-flow with `br` or `cond_br` is
    also possible. Every process must either contain an infinite loop or
    terminate with the `llhd.halt` terminator.

    How does a process compare to functions and entities?

    | Unit     | Paradigm     | Timing    | Models                         |
    |----------|--------------|-----------|--------------------------------|
    | Function | control-flow | immediate | Computation in zero time       |
    | Process  | control-flow | timed     | Behavioral circuit description |
    | Entity   | data-flow    | timed     | Structural circuit description |

    Examples:

    ```mlir
    hw.module @top() {
      llhd.process {
        br ^bb1
      ^bb1:
        llhd.halt
      }
    }
    ```
  }];

  let regions = (region MinSizedRegion<1>: $body);

  let assemblyFormat = "attr-dict-with-keyword $body";
}

def ConnectOp : LLHDOp<"con", [
    SameTypeOperands,
    HasParent<"hw::HWModuleOp">
  ]> {
  let summary = "Connect two signals.";
  let description = [{
    The `con` instruction connects two signals such that they essentially become
    one signal. All driven values on one signal will be reflected on the other.
  }];

  let arguments = (ins InOutType:$lhs,
                       InOutType:$rhs);

  let assemblyFormat = [{
    operands attr-dict `:` qualified(type($lhs))
  }];

  let hasCanonicalizeMethod = 1;
}

def WaitOp : LLHDOp<"wait", [
    Terminator,
    AttrSizedOperandSegments,
    HasParent<"ProcessOp">,
    DeclareOpInterfaceMethods<BranchOpInterface>
  ]> {
  let summary = "Suspends execution of a process.";
  let description = [{
    The `wait` instruction suspends execution of a process until any of the
    observed signals change or a fixed time interval has passed. Execution
    resumes at the specified basic block with the passed arguments.
    * This is a terminator instruction.
    * This instruction is only allowed in processes (`llhd.process`).

    Example:

    ```mlir
    llhd.wait ^bb1
    llhd.wait for %time, ^bb1(%time : !llhd.time)
    llhd.wait (%0, %1 : !hw.inout<i64>, !hw.inout<i1>), ^bb1(%1 : !hw.inout<i1>)
    llhd.wait for %time, (%0, %1 : !hw.inout<i64>, !hw.inout<i1>),
      ^bb1(%1, %0 : !hw.inout<i1>, !hw.inout<i64>)
    ```
  }];

  let arguments = (ins Variadic<InOutType>:$obs,
                       Optional<LLHDTimeType>:$time,
                       Variadic<AnyType>:$destOps);

  let successors = (successor AnySuccessor:$dest);

  let assemblyFormat = [{
    (`for` $time^ `,`)? (`(`$obs^ `:` qualified(type($obs))`)` `,`)?
    $dest (`(` $destOps^ `:` qualified(type($destOps)) `)`)? attr-dict
  }];
}

def HaltOp : LLHDOp<"halt", [Terminator, HasParent<"ProcessOp">]> {
  let summary = "Terminates execution of a process.";
  let description = [{
    The `halt` instruction terminates execution of a process. All processes
    must halt eventually or consist of an infinite loop.
  }];

  let assemblyFormat = "attr-dict";
}
