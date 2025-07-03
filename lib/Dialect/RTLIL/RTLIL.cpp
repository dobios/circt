// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

#include "mlir/IR/Builders.h"
#include "mlir/IR/OpImplementation.h"
#include "mlir/IR/DialectImplementation.h"
#include "llvm/ADT/TypeSwitch.h"

#include "circt/Dialect/RTLIL/RTLIL.h"
#include "circt/Dialect/RTLIL/RTLILOps.h"

using namespace mlir;
using namespace circt::rtlil;

//===----------------------------------------------------------------------===//
// RTLIL dialect.
//===----------------------------------------------------------------------===//

#include "circt/Dialect/RTLIL/RTLILOpsDialect.cpp.inc"
#include "circt/Dialect/RTLIL/RTLILEnums.cpp.inc"

#define GET_ATTRDEF_CLASSES
#include "circt/Dialect/RTLIL/RTLILAttrDefs.cpp.inc"
#undef GET_ATTRDEF_CLASSES

#define GET_TYPEDEF_CLASSES
#include "circt/Dialect/RTLIL/RTLILOpsTypes.cpp.inc"
#undef GET_TYPEDEF_CLASSES

void RTLILDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "circt/Dialect/RTLIL/RTLILOps.cpp.inc"
      >();
  addAttributes<
#define GET_ATTRDEF_LIST
#include "circt/Dialect/RTLIL/RTLILAttrDefs.cpp.inc"
    >();
  addTypes<
#define GET_TYPEDEF_LIST
#include "circt/Dialect/RTLIL/RTLILOpsTypes.cpp.inc"
    >();
}