// RUN: circt-opt %s --convert-hw-to-rtlil | FileCheck %s

// CHECK: [[ORMOD:@"\\\\ormod_[0-9]*"]]
hw.module @ormod(in %x: i32, in %y: i32, out res1: i32, out res2: i32) {
  // CHECK-DAG: "rtlil.wire"() {{.*}}name = "\\x_[[XIN:[0-9]+]]"{{.*}}port_id = 1 {{.*}}port_input = true{{.*}}port_output = false
  // CHECK-DAG: "rtlil.wire"() {{.*}}name = "\\y_[[YIN:[0-9]+]]"{{.*}}port_id = 2 {{.*}}port_input = true{{.*}}port_output = false
  // CHECK-DAG: "rtlil.wire"() {{.*}}name = "\\res1_[[RES1OUT:[0-9]+]]"{{.*}}port_id = 3 {{.*}}port_input = false{{.*}}port_output = true
  // CHECK-DAG: "rtlil.wire"() {{.*}}name = "\\res2_[[RES2OUT:[0-9]+]]"{{.*}}port_id = 4 {{.*}}port_input = false{{.*}}port_output = true
  %1 = hw.constant 500 : i32
  %2 = hw.constant 700 : i32
  %res1 = comb.or %x, %1 : i32
  %res2 = comb.or %y, %2 : i32
  hw.output %res1, %res2 : i32, i32
}

// CHECK-LABEL: @"\\test_{{[0-9]*}}"
hw.module @test(in %x : i32, in %y : i32) {
  // CHECK-DAG: "rtlil.instance"(%[[X:.+]], %[[Y:.+]], %[[RES1:.+]], %[[RES2:.+]]) <{{{.*}}ports = ["\\x_[[XIN]]", "\\y_[[YIN]]", "\\res1_[[RES1OUT]]", "\\res2_[[RES2OUT]]"]{{.*}}type = [[ORMOD]]}> : (!rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>, !rtlil<val[32 : i32]>) -> ()
  %1, %2 = hw.instance "instance1" @ormod(x: %x : i32, y: %y : i32) -> (res1: i32, res2: i32)
}