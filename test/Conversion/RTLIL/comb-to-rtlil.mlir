// RUN: circt-opt %s --convert-comb-to-rtlil | FileCheck %s

// CHECK-LABEL: @test
hw.module @test(in %arg0: i32, in %arg1: i32, in %arg2: i32, in %arg3: i32, out out0: i32, out out1: i32) {
  // CHECK-DAG: "rtlil.cell"(%[[OP1:.+]], %[[OP2:.+]], %[[RES1:.+]]) <{{.*name = "comb.and".*type = "\$and".*}}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>) -> ()
  // CHECK-DAG: "rtlil.cell"(%[[OP3:.+]], %[[OP4:.+]], %[[RES2:.+]]) <{{.*name = "comb.and".*type = "\$and".*}}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>) -> ()
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