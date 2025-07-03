add_circt_conversion_library(CIRCTCombToRTLIL
  CombToRTLIL.cpp

  DEPENDS
  CIRCTConversionPassIncGen

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
