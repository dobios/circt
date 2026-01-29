add_circt_library(CIRCTFirtool
  Firtool.cpp

  LINK_LIBS PUBLIC
  CIRCTExportVerilog
  CIRCTFIRRTLToHW
  CIRCTFIRRTLTransforms
  CIRCTHWToBTOR2
  CIRCTHWToRTLIL
  CIRCTHWTransforms
  CIRCTLTLToCore
  CIRCTOMTransforms
  CIRCTSeqToSV
  CIRCTSimToSV
  CIRCTSeqTransforms
  CIRCTSVTransforms
  CIRCTTransforms
  CIRCTVerifToSV
  CIRCTVerifTransforms

  MLIRIR
  MLIRSupport
  MLIRTransforms
)
