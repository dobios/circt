// RUN: circt-opt %s --verify-diagnostics

module @"\\add" {

}

module @top {
  %1 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %2 = "rtlil.wire"() <{name="$2", is_signed = true, port_input = false, port_output = true, upto = true, port_id = 10 : i32, start_offset = 3 : i32}> : () -> !rtlil<val[64 : i32]>

  %3 = "rtlil.const"() <{value = [0 : i8, 1 : i8, 2 : i8, 3 : i8, 4 : i8]}> : () -> !rtlil<val[5 : i32]>
  %4 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %5 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[32 : i32]>
  %6 = "rtlil.const"() <{value = [0 : i8, 1 : i8, 2 : i8, 3 : i8, 4 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8]}> : () -> !rtlil<val[32 : i32]>

  "rtlil.and"(%1, %6, %4) <{name="$7",width= 32 : i32, opsSigned = 0 : i32}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>) -> ()
  "rtlil.or"(%1, %6, %4) <{name="$7",width= 32 : i32, opsSigned = 0 : i32}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>) -> ()
  "rtlil.sub"(%1, %6, %4) <{name="$7",width= 32 : i32, opsSigned = 0 : i32}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>) -> ()

  %8 = "rtlil.wire"() <{name="$1", is_signed = false}> : () -> !rtlil<val[1 : i32]>
  "rtlil.gt"(%1, %6, %8) <{name="$7",width= 32 : i32, opsSigned = 0 : i32}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[1 : i32]>) -> ()
  "rtlil.eq"(%1, %6, %8) <{name="$7",width= 32 : i32, opsSigned = 0 : i32}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[1 : i32]>) -> ()
  "rtlil.ne"(%1, %6, %8) <{name="$7",width= 32 : i32, opsSigned = 0 : i32}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[1 : i32]>) -> ()
  "rtlil.ge"(%1, %6, %8) <{name="$7",width= 32 : i32, opsSigned = 0 : i32}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[1 : i32]>) -> ()
  "rtlil.le"(%1, %6, %8) <{name="$7",width= 32 : i32, opsSigned = 0 : i32}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[1 : i32]>) -> ()
  "rtlil.lt"(%1, %6, %8) <{name="$7",width= 32 : i32, opsSigned = 0 : i32}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[1 : i32]>) -> ()

  %clk = "rtlil.wire"() <{name="\\clk", is_signed = false}> : () -> !rtlil<val[1 : i32]>

  "rtlil.dff"(%clk, %6, %1) <{name="$7",width= 32 : i32}> : (!rtlil<val[1 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>) -> ()

  "rtlil.aldff"(%clk, %6, %clk, %6, %1) <{name="$7",width= 32 : i32}> : (!rtlil<val[1 : i32]>, !rtlil<val[32 : i32]>,!rtlil<val[1 : i32]>,!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>) -> ()

  "rtlil.instance"(%1, %6) <{name="$inst", type=@"\\add", ports = ["input", "output"], parameters = []}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>) -> ()
}