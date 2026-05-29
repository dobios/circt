# Lambda Calculus Dialect

This dialect provides a collection of operations useful for encoding purely functional concepts.
The goal of the lambda calculus dialect is to, as the name suggests, better capture the high-level design information held by front-ends implementing a functional programming paradigm. 
This should enable better support for functional hardware languages, such as [Clash](https://clash-lang.org/) or [Spade](https://spade-lang.org/), in CIRCT. 

[TOC]

## Introduction  

The current design of the core dialects is highly focused around Register Transfer Level (RTL)-based design paradigms, with a few exceptions that are more HLS-y.  
This focus is mainly as a result of these dialects being created initially to serve as a lower-level IR for FIRRTL, which itself is RTL-based.  
While there has been some effort to generalize this, there are still several operations in the core dialects that are exclusively used by the FIRRTL front-end, e.g. `seq.firreg` or `seq.firmem` ops, even though generic alternatives exist, e.g. `seq.compreg` and `seq.hlmem` respectively.  
  
This means that front-ends that use non-RTL based elements must completely elaborate away these notions before reaching the core dialects, meaning that any optimizations that might be enabled by this higher level structural information must be relegated to the front-end itself, making it difficult to share optimizations across e.g. functional front-ends. 

This is where the lambda calculus (`lc`) dialect comes in.   
The goal here is to act as a specialty dialect that encodes high-level functional constructs present in languages such as [Clash](https://clash-lang.org/) or [Spade](https://spade-lang.org/).  
This high-level structural information can then be used to implement shared functional optimizations that would otherwise be difficult to perform in a front-end directly or in the context of the core dialects.  

The main components that we want to encode in `lc` are core elements from functional languages, that are currently not possible to encode explicitly in the core dialects, i.e.  

1. **Algebraic Data Types (ADTs)**: A core component of all modern functional languages is the concept of ADTs, which allow the user to specific an abstract data type with sub-types that are mainly composed of data components (think of struct fields) that can then be used in a **pattern match** (another key concept we need to support) in order to specify the behavior of a certain sub-case. In hardware terms, think of FSMs as the ADT, and defining how each state behaves as a pattern match, for low-level programmers, think of a series of structs that you want to use as an enum.  

2. **Lambdas**: Unlike the functions available in MLIR's `func` dialect, lambdas represent anonymous *first-class* objects. This means that a lambda in `lc` is a value in itself and can be used as a block argument. Not only that but lambdas can take other lambdas as input, meaning that they can describe *higer-order functions*, i.e. functions that operate on, and result in, other functions. These additional functionalities are a core component of any functional language, which is why we need to encode as such in CIRCT.    

3. **Recursion**: Probably the most important feature in any functional language is recursion. This allows one to describe self-looping function or pattern matches in a compact and intuitive manner. Recursion just so happens to map cleaning to hardware, as cycles are quite common in designs. We encode recursion in `lc` using *recursive value bindings*, which allow us to call a lambda in a recursive loop by *binding* one of its inputs recursively to its outputs. This enables an easy encoding of strucutres representing moore or mealy machines.
 
## Example: Clash  

Here is an example of how the use of the `lc` dialect can help retain an FSM and map it to the more appropriate `fsm` dialect.  

```hs
bar :: (Num a, Eq a, Integral a) => a -> a
bar x = x * x * x

type I8 = Signed 8
data State = Idle | Busy I8 | Done I8
     deriving (Generic, NFDataX)
     
fsm :: I8 -> State -> (State, I8)
fsm 0  Idle     = (Idle,         0)
fsm op Idle     = (Busy op,      0)
fsm 0  (Busy x) = (Busy x,       0)
fsm _  (Busy x) = (Done (bar x), 0)
fsm 0  (Done x) = (Done x, (bar x))
fsm _  _        = (Idle,         0)

controller 
  :: (HiddenClockResetEnable dom) 
  => Signal dom (Signed 8) 
  -> Signal dom (Signed 8)
controller input = mealy (flip fsm) Idle input

topEntity
  :: Clock System
  -> Reset System
  -> Enable System
  -> Signal System (Signed 8)
  -> Signal System (Signed 8)
topEntity = exposeClockResetEnable controller
```

Using `lc` we can retain all the high-level information present in the clash source directly in the compiler.

```mlir  
hw.module @topEntity (%op: i8, %clk: !seq.clock, %rst: i1, %en: i1) -> (i8) {
  %bar = lc.lambda (%x: i8) -> (i8) {
    %0 = comb.mul %x, %x, %x : i8
    lc.yield %0: i8
  } 
  
  lc.adt @State {
    lc.adt_case @Idle
    lc.adt_case @Busy(x: i8)
    lc.adt_case @Done(x: i8)
  }
  
  %fsm = lc.lambda (%state: !lc.adt_type<@State>, %op: i8) 
    -> (s: !lc.adt_type<@State>, i8) {
    %rs, %ro = lc.adt_match %state -> (!lc.adt_type<@State>, i8) {
      lc.match_case @State::@Idle {
        %c0_i8 = hw.constant 0: i8
        %op_0 = comb.icmp bin eq %op, %c0_i8 : i8 
        %rs_0 = lc.adt_constant @State::@Idle: !lc.adt_type<@State>
        %rs_1 = lc.adt_constant @State::@Busy (x: %op)
          : !lc.adt_type<@State>
        %mux_state = comb.mux %op_0, %rs_0, %rs_1
          : !lc.adt_type<@State>
        lc.yield %mux_state, %c0_i8: !lc.adt_type<@State>, i8
      }
      
      lc.match_case @State::@Busy (%x : i8) {
        %c0_i8 = hw.constant 0: i8
        %op_0 = comb.icmp bin eq %op, %c0_i8 : i8 
        %rs_0 = lc.adt_constant @State::@Busy (x: %x)
          : !lc.adt_type<@State>
        %bar_x = lc.call %bar (%x) : i8
        %rs_1 = lc.adt_constant @State::@Done (x: %bar_x)
          : !lc.adt_type<@State>
        %mux_state = comb.mux %op_0, %rs_0, %rs_1
          : !lc.adt_type<@State>
        lc.yield %mux_state, %c0_i8: !lc.adt_type<@State>, i8
      }
      
      lc.match_case @State::@Done (%x : i8) {
        %c0_i8 = hw.constant 0: i8
        %op_0 = comb.icmp bin eq %op, %c0_i8 : i8 
        %ro = comb.mux %op_0, %x, %c0_i8: i8
        %rs_0 = lc.adt_constant @State::@Done (x: %x)
          : !lc.adt_type<@State>
        %rs_1 = lc.adt_constant @State::@Idle: !lc.adt_type<@State>
        %mux_state = comb.mux %op_0, %rs_0, %rs_1
          : !lc.adt_type<@State>
        lc.yield %mux_state, %ro: !lc.adt_type<@State>, i8
      }
    }
    lc.yield %rs, %ro
  }
  
  %controller = lc.lambda (%input: i8) -> (i8) {
    %l_rec = lc.lrec %fsm ("sn", %input)
      where ("sn": s: !lc.adt_type<@State>) on posedge %clk
        : !lc.lambda_type<<!lc.adt_type<@State>>, <i8>>
    %i = lc.adt_constant @State::@Idle : !lc.adt_type<@State>
    %v = lc.call %l_rec (%i) : i8
    lc.yield %v : i8
  }
  
  %out = lc.call %controller (%op) : i8
  hw.output %out: i8
}
```  

This mapping can be done trivially from systemFC (the haskell compiler's intermediate representation), without having to do any costly analysis of the haskell source. 
We can then easily analyze the structure of our design in CIRCT, and e.g. identify the presence of an FSM by analysing the body of the recurcive value biding defined in the source's [`mealy`](https://hackage-content.haskell.org/package/clash-prelude-1.8.2/docs/Clash-Prelude-Mealy.html) function and in `lc`'s `lc.lrec` operation.  
  
```mlir
hw.module @topEntity (%op: i8, %clk: !seq.clock, %rst: i1, %en: i1) -> (i8) {
  // This is converted from the body of the controller lambda
  fsm.machine @fsm(%input: i8) -> i8 attributes {initialState = "Idle"} {
    // Represents the input to the ADT cases for Busy and Done
    %x = fsm.variable "x" {initial_value = 0 : i8} : i8
    // Transitions are cases of the pattern match
    // This op is converted from lc.match_case @State::@Idle
    fsm.state @Idle output {
        %c0_i8 = hw.constant 0: i8
        fsm.output %c0_i8 : i8
    } transitions {
        fsm.transition @Idle guard {
            %op_0 = comb.icmp bin eq %input, %c0_i8 : i8 
            fsm.return %op_0 : i1
        }
        fsm.transition @Busy guard {
            // Since our source selects the state using a mux, this gets converted 
            // to the inverse of our mux selector
            %0 = comb.icmp bin eq %input, %c0_i8 : i8 
            %true = hw.constant true : i1
            %1 = comb.xor %0, %true : i1
            fsm.return %1 : i1
        } action {
            fsm.update %x, %input : i8
        }
    }
    // This op is converted from lc.match_case @State::@Busy
    fsm.state @Busy output {
        %c0_i8 = hw.constant 0: i8
        fsm.output %c0_i8 : i8
    } transitions {
        fsm.transition @Busy guard {
            %op_0 = comb.icmp bin eq %input, %c0_i8 : i8 
            fsm.return %op_0 : i1
        } // no action is generated since the pattern match reuses the input as argument

        fsm.transition @Done guard {
            %0 = comb.icmp bin eq %input, %c0_i8 : i8 
            %true = hw.constant true : i1
            %1 = comb.xor %0, %true : i1
            fsm.return %1 : i1
        } action {
            // the body of the lambda "bar" gets inlined here
            // since it was only ever used once.
            %bar_x = comb.mul %x, %x, %x : i8
            fsm.update %x, %bar_x : i8
        }
    }

    fsm.state @Done output {
        %c0_i8 = hw.constant 0: i8
        %ro = comb.mux %op_0, %x, %c0_i8: i8
        fsm.output %ro : i8
    } transitions {
        fsm.transition @Done guard {
            %op_0 = comb.icmp bin eq %input, %c0_i8 : i8 
            fsm.return %op_0 : i1
        } 

        fsm.transition @Idle guard {
             %0 = comb.icmp bin eq %input, %c0_i8 : i8 
            %true = hw.constant true : i1
            %1 = comb.xor %0, %true : i1
            fsm.return %1 : i1
        }
    }
  }

  %out = fsm.hw_instance "controller" @fsm(%op) : (i8) -> i8
  hw.output %out: i8
}
```

## Types

The `lc` dialect encodes ADTs and Lambdas in the type system using:
```mlir
!lc.adt_type<@sym> // @Sym refers to the symbol of an `lc.adt` op
!lc.lambda_type<<input_types...>, <output_types...>>
```
This allows the type system to enforce that the correct ADT is used e.g. in a pattern match. 
Without this one could mix two cases from different ADTs in a single pattern match, which would not make sense.

For example:
```mlir
lc.adt @C_State {
    lc.adt_case @Idle
    lc.adt_case @Busy(x: i8)
    lc.adt_case @Done(x: i8)
}

lc.adt @L_State {
    lc.adt_case @On
    lc.adt_case @Off
    lc.adt_case @Unknown
}

%lbd = lc.lambda (%state: !lc.adt_type<@C_State>) -> ... {...}
%s = lc.adt_constant @L_State::@On : !lc.adt_type<@L_State>

// Typing error, %s is not of type @C_State
%0 = lc.call %lbd, %s

%rs, %ro = lc.adt_match %state -> (!lc.adt_type<@C_State>, ...) {
    // Type error, @L_State::@On is not a case of @C_State
    lc.match_case @L_State::@On {...}
    ...
}

```

Lambda types are used to specify lambdas in block arguments, where regular function types would not be allowed.

For example:
```mlir
lc.lambda (%f : !lc.lambda_type<<i1, i1>, <i2>>) -> i2 {...}
```

[include "Dialects/LCTypes.md"]

## Operations

[include "Dialects/LCOps.md"]  
 
## Further Reading  

To learn more about the motivation behind `lc` and a concrete application of it, I recommend reading the LATTE'26 paper: [Encoding Purely Functional Languages in an RTL-based Compiler](https://capra.cs.cornell.edu/latte26/paper/latte26-final14.pdf).  

