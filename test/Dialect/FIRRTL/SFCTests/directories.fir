; RUN: firtool %s -disable-all-randomization -disable-opt -annotation-file %s.sitestblackboxes.anno.json | FileCheck %s -check-prefixes=CHECK,SITEST_NODUT
; RUN: firtool %s -disable-all-randomization -disable-opt -annotation-file %s.sitestblackboxes.anno.json -annotation-file %s.markdut.anno.json | FileCheck %s -check-prefixes=CHECK,SITEST_DUT
; RUN: firtool %s -repl-seq-mem -repl-seq-mem-file=mems.conf -disable-all-randomization -disable-opt | FileCheck %s -check-prefixes=CHECK,MEMS_NODUT
; RUN: firtool %s -repl-seq-mem -repl-seq-mem-file=mems.conf -disable-all-randomization -disable-opt -annotation-file %s.markdut.anno.json | FileCheck %s -check-prefixes=CHECK,MEMS_DUT
; RUN: firtool %s -disable-all-randomization -disable-opt -annotation-file %s.memtoregofvec.anno.json | FileCheck %s -check-prefixes=CHECK,MEMTOREG_NODUT
; RUN: firtool %s -disable-all-randomization -disable-opt -annotation-file %s.memtoregofvec.anno.json -annotation-file %s.markdut.anno.json | FileCheck %s -check-prefixes=CHECK,MEMTOREG_DUT
; RUN: firtool %s -disable-all-randomization -disable-opt -repl-seq-mem -repl-seq-mem-file=mems.conf -annotation-file %s.sitestblackboxes.anno.json --ir-verilog | FileCheck %s -check-prefix=MLIR_OUT

FIRRTL version 4.0.0
circuit TestHarness:
  ; Foo* are instantiated only by the TestHarness
  module Foo:

    mem foo_m :
      data-type => UInt<8>
      depth => 1
      reader => r
      writer => w
      read-latency => 1
      write-latency => 1
      read-under-write => undefined

    mem foo_combmem :
      data-type => UInt<8>
      depth => 1
      reader => r
      writer => w
      read-latency => 0
      write-latency => 1
      read-under-write => undefined

    foo_m is invalid
    foo_combmem is invalid

  extmodule Foo_BlackBox:
    defname = Foo_BlackBox

  ; Bar* are instantiated only by the DUT
  module Bar:

    mem bar_m :
      data-type => UInt<8>
      depth => 2
      reader => r
      writer => w
      read-latency => 1
      write-latency => 1
      read-under-write => undefined

    mem bar_combmem :
      data-type => UInt<8>
      depth => 2
      reader => r
      writer => w
      read-latency => 0
      write-latency => 1
      read-under-write => undefined

    bar_m is invalid
    bar_combmem is invalid

  extmodule Bar_BlackBox:
    defname = Bar_BlackBox

  ; Baz* are instantiated by both the TestHarness and the DUT
  module Baz:

    mem baz_m :
      data-type => UInt<8>
      depth => 3
      reader => r
      writer => w
      read-latency => 1
      write-latency => 1
      read-under-write => undefined

    mem baz_combmem :
      data-type => UInt<8>
      depth => 3
      reader => r
      writer => w
      read-latency => 0
      write-latency => 1
      read-under-write => undefined

    baz_m is invalid
    baz_combmem is invalid

  extmodule Baz_BlackBox:
    defname = Baz_BlackBox

  ; This is the design-under-test.  This is marked as such by a separate,
  ; optional annotation file.
  module DUT:

    inst bar of Bar
    inst bar_bbox of Bar_BlackBox
    inst baz of Baz
    inst baz_bbox of Baz_BlackBox

  ; This is the Test Harness, i.e., the top of the design.
  public module TestHarness:

    inst foo of Foo
    inst foo_bbox of Foo_BlackBox
    inst dut of DUT
    inst baz of Baz
    inst baz_bbox of Baz_BlackBox


; CHECK:            module Foo()
; MEMTOREG_DUT-NOT:   reg [7:0] foo_combmem
; MEMTOREG_NODUT:     reg [7:0] foo_combmem
; CHECK:            endmodule

; CHECK:            module Bar()
; MEMTOREG_DUT:       reg [7:0] bar_combmem
; MEMTOREG_NODUT:     reg [7:0] bar_combmem
; CHECK:            endmodule

; CHECK:            module Baz()
; MEMTOREG_DUT:       reg [7:0] baz_combmem
; MEMTOREG_NODUT:     reg [7:0] baz_combmem
; CHECK:            endmodule

; SITEST_DUT:       FILE "testbench.sitest.json"
; SITEST_DUT-NOT:   FILE
; SITEST_DUT:         "Foo_BlackBox"

; SITEST_DUT:       FILE "design.sitest.json"
; SITEST_DUT-NOT:   FILE
; SITEST_DUT-DAG:     "Bar_BlackBox",
; SITEST_DUT-DAG:     "Baz_BlackBox"

; SITEST_NODUT:     FILE "testbench.sitest.json"
; SITEST_NODUT-NOT: FILE

; MLIR_OUT:  om.class @SitestBlackBoxModulesSchema(%basepath: !om.basepath, %moduleName_in: !om.string) {
; MLIR_OUT:    om.class.field @moduleName, %moduleName_in : !om.string
; MLIR_OUT:  }

; MLIR_OUT:  om.class @SitestBlackBoxMetadata(%basepath: !om.basepath)
; MLIR_OUT:    %0 = om.constant "Foo_BlackBox" : !om.string
; MLIR_OUT:    %1 = om.object @SitestBlackBoxModulesSchema(%basepath, %0) : (!om.basepath, !om.string) -> !om.class.type<@SitestBlackBoxModulesSchema>
; MLIR_OUT:    %2 = om.constant "Bar_BlackBox" : !om.string
; MLIR_OUT:    %3 = om.object @SitestBlackBoxModulesSchema(%basepath, %2) : (!om.basepath, !om.string) -> !om.class.type<@SitestBlackBoxModulesSchema>
; MLIR_OUT:    %4 = om.constant "Baz_BlackBox" : !om.string
; MLIR_OUT:    %5 = om.object @SitestBlackBoxModulesSchema(%basepath, %4) : (!om.basepath, !om.string) -> !om.class.type<@SitestBlackBoxModulesSchema>
; MLIR_OUT:    om.class.field @[[V1:.+]], %1 : !om.class.type<@SitestBlackBoxModulesSchema>
; MLIR_OUT:    om.class.field @[[V2:.+]], %3 : !om.class.type<@SitestBlackBoxModulesSchema>
; MLIR_OUT:    om.class.field @[[V3:.+]], %5 : !om.class.type<@SitestBlackBoxModulesSchema>
; MLIR_OUT:  }

; MLIR_OUT:  om.class @MemorySchema(%basepath: !om.basepath, %name_in: !om.string, %depth_in: !om.integer, %width_in: !om.integer, %maskBits_in: !om.integer, %readPorts_in: !om.integer, %writePorts_in: !om.integer, %readwritePorts_in: !om.integer, %writeLatency_in: !om.integer, %readLatency_in: !om.integer, %hierarchy_in: !om.list<!om.path>, %inDut_in: i1, %extraPorts_in: !om.list<!om.class.type<@ExtraPortsMemorySchema>>
; MLIR_OUT:    om.class.field @name, %name_in : !om.string
; MLIR_OUT:    om.class.field @depth, %depth_in : !om.integer
; MLIR_OUT:    om.class.field @width, %width_in : !om.integer
; MLIR_OUT:    om.class.field @maskBits, %maskBits_in : !om.integer
; MLIR_OUT:    om.class.field @readPorts, %readPorts_in : !om.integer
; MLIR_OUT:    om.class.field @writePorts, %writePorts_in : !om.integer
; MLIR_OUT:    om.class.field @readwritePorts, %readwritePorts_in : !om.integer
; MLIR_OUT:    om.class.field @writeLatency, %writeLatency_in : !om.integer
; MLIR_OUT:    om.class.field @readLatency, %readLatency_in : !om.integer
; MLIR_OUT:    om.class.field @hierarchy, %hierarchy_in : !om.list<!om.path>
; MLIR_OUT:    om.class.field @extraPorts, %extraPorts_in : !om.list<!om.class.type<@ExtraPortsMemorySchema>>
; MLIR_OUT:  om.class @MemoryMetadata(%basepath: !om.basepath)
; MLIR_OUT:     om.path_create instance %basepath @memNLA
; MLIR_OUT:     om.list_create
; MLIR_OUT:     om.object @MemorySchema
; MLIR_OUT:     om.constant "foo_m_ext" : !om.string
; MLIR_OUT:     om.constant #om.integer<1 : ui64> : !om.integer
; MLIR_OUT:     om.constant #om.integer<8 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<0 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:     om.path_create instance %basepath @memNLA_0
; MLIR_OUT:     om.list_create
; MLIR_OUT:     om.object @MemorySchema
; MLIR_OUT:     om.constant "bar_m_ext" : !om.string
; MLIR_OUT:     om.constant #om.integer<2 : ui64> : !om.integer
; MLIR_OUT:     om.constant #om.integer<8 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<0 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:     om.path_create instance %basepath @memNLA_1
; MLIR_OUT:     om.path_create instance %basepath @memNLA_2
; MLIR_OUT:     om.list_create
; MLIR_OUT:     om.object @MemorySchema
; MLIR_OUT:     om.constant "baz_m_ext" : !om.string
; MLIR_OUT:     om.constant #om.integer<3 : ui64> : !om.integer
; MLIR_OUT:     om.constant #om.integer<8 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<0 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:     om.constant #om.integer<1 : ui32> : !om.integer
; MLIR_OUT:    om.class.field @foo_m_ext_field
; MLIR_OUT:    om.class.field @bar_m_ext_field
; MLIR_OUT:    om.class.field @baz_m_ext_field

; SITEST_NODUT:     FILE "design.sitest.json"
; SITEST_NODUT-NOT: FILE
; SITEST_NODUT-DAG:   "Foo_BlackBox"
; SITEST_NODUT-DAG:   "Bar_BlackBox"{{,?}}
; SITEST_NODUT-DAG:   "Baz_BlackBox"{{,?}}

; MEMS_DUT:         FILE "metadata{{[/\]}}seq_mems.json"
; MEMS_DUT-NOT:     FILE
; MEMS_DUT-DAG:       "DUT.bar.bar_m.bar_m_ext"
; MEMS_DUT-DAG:       "DUT.baz.baz_m.baz_m_ext"

; MEMS_NODUT:       FILE "metadata{{[/\]}}seq_mems.json"
; MEMS_NODUT-NOT:   FILE
; MEMS_NODUT-DAG:    "TestHarness.foo.foo_m.foo_m_ext"
; MEMS_NODUT-DAG:    "TestHarness.dut.bar.bar_m.bar_m_ext"
; MEMS_NODUT-DAG:    "TestHarness.dut.baz.baz_m.baz_m_ext"
; MEMS_NODUT-DAG:    "TestHarness.baz.baz_m.baz_m_ext"
