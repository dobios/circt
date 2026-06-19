add_circt_conversion_library(CIRCTRTLILCommon
  RTLILCommon.cpp

  LINK_COMPONENTS
  Core

  LINK_LIBS PUBLIC
  CIRCTHW
  CIRCTComb
  CIRCTRTLIL
  MLIRTransforms
  MLIRPass
  MLIRSupport
)

