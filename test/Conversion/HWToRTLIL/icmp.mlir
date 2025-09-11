// RUN: circt-opt %s --convert-hw-to-rtlil | FileCheck %s

// CHECK-LABEL: @"\\cmpmod_{{[0-9]*}}"
hw.module @cmpmod(in %x: i32) {
  // CHECK-DAG: [[X:%[0-9]+]] = "rtlil.wire"() {{.*}}name = "\\x_[[XIN:[0-9]+]]"{{.*}}port_id = 1 {{.*}}port_input = true{{.*}}port_output = false
  // CHECK-DAG: [[CONST500:%[0-9]+]] = "rtlil.const"() {{.*}}value = [0 : i8, 0 : i8, 1 : i8, 0 : i8, 1 : i8, 1 : i8, 1 : i8, 1 : i8, 1 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8]{{.*}} : () -> !rtlil<val[32 : i32]>
  // CHECK-DAG: [[CONST700:%[0-9]+]] = "rtlil.const"() {{.*}}value = [0 : i8, 0 : i8, 1 : i8, 1 : i8, 1 : i8, 1 : i8, 0 : i8, 1 : i8, 0 : i8, 1 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8]{{.*}} : () -> !rtlil<val[32 : i32]>
  %1 = hw.constant 500 : i32
  %2 = hw.constant 700 : i32
  // CHECK-DAG: "rtlil.eq"([[X]], [[CONST700]], [[RES:%[0-9]+]]){{.*}}ports = ["\\A", "\\B", "\\Y"]{{.*}}type = "$eq"{{.*}}width = 32
  // CHECK-DAG: [[RES]] = "rtlil.wire"(){{.*}}: () -> !rtlil<val[1 : i32]>
  %res1 = comb.icmp bin eq %x, %2 : i32
  %res2 = comb.icmp bin slt %1, %x : i32
  // CHECK-DAG: "rtlil.lt"([[CONST500]], [[X]], [[RES2:%[0-9]+]]){{.*}}opsSigned = 1 : i32{{.*}}ports = ["\\A", "\\B", "\\Y"]{{.*}}type = "$lt"{{.*}}width = 32
  // CHECK-DAG: [[RES2]] = "rtlil.wire"(){{.*}}: () -> !rtlil<val[1 : i32]>
}
