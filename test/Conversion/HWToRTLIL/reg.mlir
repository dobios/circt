// RUN: circt-opt %s --convert-hw-to-rtlil | FileCheck %s

// CHECK-LABEL: @"\\regmod_{{[0-9]*}}"
hw.module @regmod(in %clk : !seq.clock, in %reset : i1) {
  // CHECK-DAG: [[CLK:%[0-9]+]] = "rtlil.wire"() {{.*}}port_id = 1 {{.*}}port_input = true{{.*}}port_output = false
  // CHECK-DAG: [[RESET:%[0-9]+]] = "rtlil.wire"() {{.*}}port_id = 2 {{.*}}port_input = true{{.*}}port_output = false
  // CHECK-DAG: [[CONST500:%[0-9]+]] = "rtlil.const"() {{.*}}value = [0 : i8, 0 : i8, 1 : i8, 0 : i8, 1 : i8, 1 : i8, 1 : i8, 1 : i8, 1 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8]{{.*}} : () -> !rtlil<val[32 : i32]>
  // CHECK-DAG: [[CONST700:%[0-9]+]] = "rtlil.const"() {{.*}}value = [0 : i8, 0 : i8, 1 : i8, 1 : i8, 1 : i8, 1 : i8, 0 : i8, 1 : i8, 0 : i8, 1 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8, 0 : i8]{{.*}} : () -> !rtlil<val[32 : i32]>
  %1 = hw.constant 500 : i32
  %2 = hw.constant 700 : i32
  // CHECK-DAG: "rtlil.dff"([[CLK]], [[CONST500]], [[RES:%[0-9]+]]){{.*}}name = "\\inner_symbol_{{[0-9]+}}"{{.*}}ports = ["\\CLK", "\\D", "\\Q"]{{.*}}type = "$dff"{{.*}}width = 32
  // CHECK-DAG: [[RES]] = "rtlil.wire"(){{.*}}: () -> !rtlil<val[32 : i32]>
  %res1 = seq.compreg sym @inner_symbol %1, %clk: i32
  // CHECK-DAG: "rtlil.aldff"([[CLK]], [[CONST500]], [[RESET]], [[CONST700]], [[RES2:%[0-9]+]]){{.*}}ports = ["\\CLK", "\\D", "\\ALOAD", "\\AD", "\\Q"]{{.*}}type = "$aldff"{{.*}}width = 32
  // CHECK-DAG: [[RES2]] = "rtlil.wire"(){{.*}}: () -> !rtlil<val[32 : i32]>
  %res2 = seq.compreg %1, %clk reset %reset, %2: i32
  // CHECK-DAG: "rtlil.dff"([[CLK]], [[CONST500]], [[RES3:%[0-9]+]]){{.*}}name = "\\inner_symbol_{{[0-9]+}}"{{.*}}ports = ["\\CLK", "\\D", "\\Q"]{{.*}}type = "$dff"{{.*}}width = 32
  // CHECK-DAG: [[RES3]] = "rtlil.wire"(){{.*}}: () -> !rtlil<val[32 : i32]>
  %res3 = seq.firreg %1 clock %clk sym @inner_symbol : i32
  // CHECK-DAG: "rtlil.aldff"([[CLK]], [[CONST500]], [[RESET]], [[CONST700]], [[RES5:%[0-9]+]]){{.*}}ports = ["\\CLK", "\\D", "\\ALOAD", "\\AD", "\\Q"]{{.*}}type = "$aldff"{{.*}}width = 32
  // CHECK-DAG: [[RES5]] = "rtlil.wire"(){{.*}}: () -> !rtlil<val[32 : i32]>
  %res5 = seq.firreg %1 clock %clk reset async %reset, %2 : i32


  // CHECK-DAG: "rtlil.aldff"([[CLK]], [[CONST500]], [[RESETNEW:%[0-9]+]], [[CONST700]], [[RES4:%[0-9]+]]){{.*}}ports = ["\\CLK", "\\D", "\\ALOAD", "\\AD", "\\Q"]{{.*}}type = "$aldff"{{.*}}width = 32
  // CHECK-DAG: "rtlil.dff"([[CLK]], [[RESET]], [[RESETBUFF:%[0-9]+]]){{.*}}
  // CHECK-DAG: "rtlil.and"([[RESETBUFF]], [[RESET]], [[RESETNEW]])
  // CHECK-DAG: [[RES4]] = "rtlil.wire"(){{.*}}: () -> !rtlil<val[32 : i32]>
  %res4 = seq.firreg %1 clock %clk reset sync %reset, %2 : i32
}
