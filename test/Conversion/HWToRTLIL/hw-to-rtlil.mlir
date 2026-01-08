// RUN: circt-opt %s --convert-hw-to-rtlil | FileCheck %s

// CHECK-LABEL: @"\\test_{{[0-9]*}}"
hw.module @test(in %arg0: i32, in %arg1: i32, in %arg2: i32, in %arg3: i32, out out0: i32, out out1: i32) {
  // CHECK-DAG: "rtlil.and"(%[[OP1:.+]], %[[OP2:.+]], %[[RES1:.+]]) <{{.*name = "\$[0-9]+".*type = "\$and".*}}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>) -> ()
  // CHECK-DAG: "rtlil.and"(%[[OP3:.+]], %[[OP4:.+]], %[[RES2:.+]]) <{{.*name = "\$[0-9]+".*type = "\$and".*}}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>) -> ()
  // CHECK-DAG: %[[OP1]] = "rtlil.wire"() <{{.*port_input = true.*}}> : () -> !rtlil<val[32 : i32]>
  // CHECK-DAG: %[[OP2]] = "rtlil.wire"() <{{.*port_input = true.*}}> : () -> !rtlil<val[32 : i32]>
  // CHECK-DAG: %[[RES1]] = "rtlil.wire"() <{{.*port_output = true.*}}> : () -> !rtlil<val[32 : i32]>
  // CHECK-DAG: %[[OP3]] = "rtlil.wire"() <{{.*port_input = true.*}}> : () -> !rtlil<val[32 : i32]>
  // CHECK-DAG: %[[OP4]] = "rtlil.wire"() <{{.*port_input = true.*}}> : () -> !rtlil<val[32 : i32]>
  // CHECK-DAG: %[[RES2]] = "rtlil.wire"() <{{.*port_output = true.*}}> : () -> !rtlil<val[32 : i32]>
  %0 = comb.and %arg0, %arg1 : i32
  %1 = comb.and %arg2, %arg3 : i32
  hw.output %0, %1 : i32, i32
}

// CHECK-LABEL: @"\\concat_{{[0-9]*}}"
hw.module @concat(in %in0 : i3, in %in1 : i2, out out0 : i5) {
  // CHECK-DAG: "rtlil.concat"(%[[OP2:.+]], %[[OP1:.+]], %[[RES:.+]]) <{{.*name = "\$[0-9]".*type = "\$concat".*}}> : (!rtlil<val[2 : i32]>, !rtlil<val[3 : i32]>, !rtlil<val[5 : i32]>) -> ()
  // CHECK-DAG: %[[OP2]] = "rtlil.wire"() <{{.*port_input = true.*}}> : () -> !rtlil<val[2 : i32]>
  // CHECK-DAG: %[[OP1]] = "rtlil.wire"() <{{.*port_input = true.*}}> : () -> !rtlil<val[3 : i32]>
  // CHECK-DAG: %[[RES]] = "rtlil.wire"() <{{.*port_input = false.*port_output = true.*}}> : () -> !rtlil<val[5 : i32]>
  %0 = comb.concat %in0, %in1 : i3, i2
  hw.output %0 : i5
}
