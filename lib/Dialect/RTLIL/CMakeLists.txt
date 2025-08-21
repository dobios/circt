add_circt_dialect_library(CIRCTRTLIL
    RTLIL.cpp
    RTLILOps.cpp
    RTLILTypes.cpp

    ADDITIONAL_HEADER_DIRS
    ${CIRCT_MAIN_INCLUDE_DIR}/circt/Dialect/RTLIL

    DEPENDS
    MLIRRTLILOpsIncGen
    MLIRRTLILAttrDefsIncGen
    MLIRRTLILEnumDefsIncGen
    MLIRRTLILInterfaceDefsIncGen
    MLIRDerivedAttributeOpInterface

	LINK_LIBS PUBLIC
	MLIRIR
	)