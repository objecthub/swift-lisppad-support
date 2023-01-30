// swift-tools-version:5.4
//
//  Package.swift
//  LispPadSupport
//  
//  A release for the LispPad REPL can be built in the following way:
//  swift build -c release -Xswiftc "-D" -Xswiftc "SPM"
//
//  This creates a release binary in .build/release/ which can be invoked like this:
//  .build/release/LispPadRepl -r .build/checkouts/swift-lispkit/Sources/LispKit/Resources Sources/LispPadRepl/Resources
//
//
//  Created by Matthias Zenger on 29/01/2023.
//  Copyright © 2023 Matthias Zenger. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import PackageDescription

let package = Package(
  name: "LispPadSupport",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .library(name: "LispPadLibraries", targets: ["LispPadLibraries"]),
    .executable(name: "LispPadRepl", targets: ["LispPadRepl"])
  ],
  dependencies: [
    .package(url: "https://github.com/objecthub/swift-lispkit.git", .branch("master"))
  ],
  targets: [
    .target(name: "LispPadLibraries",
            dependencies: [.product(name: "LispKit", package: "swift-lispkit")],
            exclude: ["Info.plist",
                      "Resources",
                      "LispPadLibraries.h",
                      "LispPadLibraries.docc"]),
    .executableTarget(name: "LispPadRepl",
                      dependencies: ["LispPadLibraries",
                                     .product(name: "LispKit", package: "swift-lispkit"),
                                     .product(name: "LispKitTools", package: "swift-lispkit")],
                      exclude: ["Info.plist",
                                "Resources"]),
  ],
  swiftLanguageVersions: [.v5]
)
