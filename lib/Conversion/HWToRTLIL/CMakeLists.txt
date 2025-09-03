add_circt_conversion_library(CIRCTHWToRTLIL
  HWToRTLIL.cpp

  DEPENDS
  CIRCTConversionPassIncGen

  LINK_COMPONENTS
  Core

  LINK_LIBS PUBLIC
  CIRCTHW
  CIRCTComb
  CIRCTRTLIL
  CIRCTRTLILCommon
  MLIRTransforms
  MLIRPass
  MLIRSupport
)
