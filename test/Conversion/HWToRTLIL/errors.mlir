// RUN: circt-opt --convert-hw-to-rtlil %s --verify-diagnostics --split-input-file

hw.module @top(in %x : i32, in %y : i32, in %z : i32) {
  %res = comb.and %x, %y, %z : i32
  // expected-error@-1 {{failed to legalize operation 'comb.and' that was explicitly marked illegal}}
}

// -----

hw.module @top(in %x : i32, in %y : i32, in %z : i32, in %select: i1) {
  %res = comb.icmp bin wne %y, %z : i32
  // expected-error@-1 {{failed to legalize operation 'comb.icmp' that was explicitly marked illegal}}
}

// -----

hw.module @top(in %x : i4, in %y : i4, in %z : i4, in %clk: !seq.clock) {
  // expected-error@+1 {{failed to legalize operation 'seq.initial' that was explicitly marked illegal}}
  %init0, %init1, %init2 = seq.initial () {
    %cst1 = hw.constant 1 : i4
    %cst2 = hw.constant 2 : i4
    %cst3 = hw.constant 3 : i4
    seq.yield %cst1, %cst2, %cst3 : i4, i4, i4
  } : () -> (!seq.immutable<i4>, !seq.immutable<i4>, !seq.immutable<i4>)
  %res = seq.compreg %z, %clk initial %init0 : i4
}

// -----

hw.module @top(in %x : i4, in %y : i4, in %z : i4, in %clk: !seq.clock) {
  %res = seq.firreg %z clock %clk preset 12 : i4
  // expected-error@-1 {{failed to legalize operation 'seq.firreg' that was explicitly marked illegal}}
}