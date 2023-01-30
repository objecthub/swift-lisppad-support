//
//  main.swift
//  LispPadRepl
//
//  Run the following command before building LispPadRepl:
//  carthage update --platform macOS
//
//  Created by Matthias Zenger on 29/01/2021.
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

import Foundation
import LispKit
import LispPadLibraries
import LispKitTools
import CommandLineKit

let name = "LispPadRepl"
let version = "1.0"
let copyright = "Copyright © 2023 Matthias Zenger"
let features = ["repl", "lisppad"]
#if SPM
let internalResources = false
#else
let internalResources = true
#endif

// Static configuration of the the LispKit framework.
Context.simplifiedDescriptions = true
LibraryRegistry.register(AppleScriptLibrary.self)
LibraryRegistry.register(AudioLibrary.self)
LibraryRegistry.register(DrawMapLibrary.self)
LibraryRegistry.register(LocationLibrary.self)
LibraryRegistry.register(SpeechLibrary.self)

// Creation of LispKit read-eval-print loop.
let repl = LispPadRepl(name: name,
                       version: version,
                       build: "",
                       copyright: copyright,
                       prompt: "> ")

// Parse and check command line arguments.
guard repl.flagsValid() else {
  exit(1)
}

// Execute the read-eval-print loop in a new thread
let main = Thread {
  // Invoke read-eval-print loop if requested.
  if repl.shouldRunRepl() {
    guard repl.configurationSuccessfull(implementationName: name,
                                        implementationVersion: version,
                                        includeInternalResources: internalResources,
                                        defaultDocDirectory: "LispPadRepl",
                                        features: features),
          repl.run() else {
      exit(1)
    }
  }
  // Regular exit of read-eval-print loop
  exit(0)
}

// Start the read-eval-print loop
main.start()

// Start the run loop to enable asynchronous APIs
RunLoop.main.run()
