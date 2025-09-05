// RUN: circt-opt %s --verify-diagnostics --split-input-file

module @top {
  %1 = "rtlil.wire"() <{name="$1"}> : () -> !rtlil<val[32 : i32]>
  // expected-error@-1 {{'rtlil.wire' op requires attribute 'is_signed'}}
}

// -----

module @top {
  %1 = "rtlil.const"() <{value = [0 : i8]}> : () -> !rtlil<val[32: i32]>
  // expected-error@-1 {{'rtlil.const' op failed to verify that bitwidth matches}}
}

// -----

module @top {
  %1 = "rtlil.const"() <{value = [5 : i8]}> : () -> !rtlil<val[1: i32]>
  // expected-error@-1 {{'rtlil.const' op attribute 'value' failed to satisfy constraint: constant multi-valued bitvec}}
}

// -----

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = false}> : () -> !rtlil<val[31 : i32]>
  %3 = "rtlil.wire"() <{name="$3", is_signed = false}> : () -> !rtlil<val[32 : i32]>

  "rtlil.and"(%1, %2, %3) <{name = "$4", width=32 : i32, opsSigned = 0 : i32}> : (!rtlil<val[32: i32]>, !rtlil<val[31: i32]>, !rtlil<val[32: i32]>) -> ()
  // expected-error@-1 {{'rtlil.and' op failed to verify that input 1 width is $width}}
}

// -----

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %3 = "rtlil.wire"() <{name="$3", is_signed = false}> : () -> !rtlil<val[32 : i32]>

  "rtlil.and"(%1, %3) <{name = "$4", width=32 : i32, opsSigned = 0 : i32}> : (!rtlil<val[32: i32]>, !rtlil<val[32: i32]>) -> ()
  // expected-error@-1 {{'rtlil.and' op failed to verify that has 3 connections}}
}

// -----

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %3 = "rtlil.wire"() <{name="$3", is_signed = false}> : () -> !rtlil<val[32 : i32]>

  "rtlil.mux"(%1, %2, %3) <{name = "$4", width=32 : i32}> : (!rtlil<val[32: i32]>, !rtlil<val[32 : i32]>, !rtlil<val[32: i32]>) -> ()
  // expected-error@-1 {{'rtlil.mux' op failed to verify that has 4 connections}}
}

// -----

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %3 = "rtlil.wire"() <{name="$3", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %select = "rtlil.wire"() <{name="$select", is_signed = false}> : () -> !rtlil<val[2 : i32]>


  "rtlil.mux"(%1, %2, %select, %3) <{name = "$4", width=32 : i32}> : (!rtlil<val[32: i32]>, !rtlil<val[32 : i32]>,!rtlil<val[2 : i32]>, !rtlil<val[32: i32]>) -> ()
  // expected-error@-1 {{'rtlil.mux' op failed to verify that input 2 width is 1}}
}

// -----

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[31 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %3 = "rtlil.wire"() <{name="$3", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %select = "rtlil.wire"() <{name="$select", is_signed = false}> : () -> !rtlil<val[1 : i32]>


  "rtlil.mux"(%1, %2, %select, %3) <{name = "$4", width=32 : i32}> : (!rtlil<val[31: i32]>, !rtlil<val[32 : i32]>,!rtlil<val[1 : i32]>, !rtlil<val[32: i32]>) -> ()
  // expected-error@-1 {{'rtlil.mux' op failed to verify that input 0 width is $width}}
}

// -----

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %3 = "rtlil.wire"() <{name="$3", is_signed = false}> : () -> !rtlil<val[1 : i32]>


  "rtlil.gt"(%1, %2, %3) <{name = "$4", width=32 : i32}> : (!rtlil<val[32: i32]>, !rtlil<val[32 : i32]>, !rtlil<val[1: i32]>) -> ()
  // expected-error@-1 {{'rtlil.gt' op requires attribute 'opsSigned'}}
}

// -----

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %3 = "rtlil.wire"() <{name="$3", is_signed = false}> : () -> !rtlil<val[1 : i32]>


  "rtlil.gt"(%1, %1, %2, %3) <{name = "$4", width=32 : i32, opsSigned = 0 : i32}> : (!rtlil<val[32: i32]>,!rtlil<val[32: i32]>, !rtlil<val[32 : i32]>, !rtlil<val[1: i32]>) -> ()
  // expected-error@-1 {{'rtlil.gt' op failed to verify that has 3 connections}}
}

// -----

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[31 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %3 = "rtlil.wire"() <{name="$3", is_signed = false}> : () -> !rtlil<val[1 : i32]>


  "rtlil.gt"(%1, %2, %3) <{name = "$4", width=32 : i32, opsSigned = 1 : i32}> : (!rtlil<val[31: i32]>,!rtlil<val[32 : i32]>, !rtlil<val[1: i32]>) -> ()
  // expected-error@-1 {{'rtlil.gt' op failed to verify that input 0 width is $width}}
}

// -----

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %3 = "rtlil.wire"() <{name="$3", is_signed = false}> : () -> !rtlil<val[32 : i32]>


  "rtlil.gt"(%1, %2, %3) <{name = "$4", width=32 : i32, opsSigned = 1 : i32}> : (!rtlil<val[32: i32]>,!rtlil<val[32 : i32]>, !rtlil<val[32: i32]>) -> ()
  // expected-error@-1 {{'rtlil.gt' op failed to verify that input 2 width is 1}}
}

// -----

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %3 = "rtlil.wire"() <{name="$3", is_signed = false}> : () -> !rtlil<val[32 : i32]>

  "rtlil.dff"(%1, %2, %3) <{name="$4", width=32 : i32}> : (!rtlil<val[32: i32]>,!rtlil<val[32 : i32]>, !rtlil<val[32: i32]>) -> ()
  // expected-error@-1 {{'rtlil.dff' op failed to verify that input 0 width is 1}}
}

// -----

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[1 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %3 = "rtlil.wire"() <{name="$3", is_signed = false}> : () -> !rtlil<val[33 : i32]>

  "rtlil.dff"(%1, %2, %3) <{name="$4", width=32 : i32}> : (!rtlil<val[1: i32]>,!rtlil<val[32 : i32]>, !rtlil<val[33: i32]>) -> ()
  // expected-error@-1 {{'rtlil.dff' op failed to verify that input 2 width is $width}}
}

// -----

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[1 : i32]>
  %reset = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[2 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %3 = "rtlil.wire"() <{name="$3", is_signed = false}> : () -> !rtlil<val[32 : i32]>

  "rtlil.aldff"(%1, %2, %reset, %3, %3) <{name="$4", width=32 : i32}> : (!rtlil<val[1: i32]>,!rtlil<val[32 : i32]>,!rtlil<val[2 : i32]>,!rtlil<val[32 : i32]>, !rtlil<val[32: i32]>) -> ()
  // expected-error@-1 {{'rtlil.aldff' op failed to verify that input 2 width is 1}}
}

// -----

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[1 : i32]>
  %reset = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[1 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %3 = "rtlil.wire"() <{name="$3", is_signed = false}> : () -> !rtlil<val[32 : i32]>

  "rtlil.aldff"(%1, %2, %reset, %3, %3, %3) <{name="$4", width=32 : i32}> : (!rtlil<val[1: i32]>,!rtlil<val[32 : i32]>,!rtlil<val[1 : i32]>,!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[32: i32]>) -> ()
  // expected-error@-1 {{'rtlil.aldff' op failed to verify that has 5 connections}}
}

// -----

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[1 : i32]>
  %reset = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[1 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = false}> : () -> !rtlil<val[64 : i32]>
  %3 = "rtlil.wire"() <{name="$3", is_signed = false}> : () -> !rtlil<val[32 : i32]>

  "rtlil.aldff"(%1, %2, %reset, %3, %3) <{name="$4", width=32 : i32}> : (!rtlil<val[1: i32]>,!rtlil<val[64 : i32]>,!rtlil<val[1 : i32]>,!rtlil<val[32 : i32]>, !rtlil<val[32: i32]>) -> ()
  // expected-error@-1 {{'rtlil.aldff' op failed to verify that input 1 width is $width}}
}