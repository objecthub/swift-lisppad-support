//
//  LispPadRepl.swift
//  LispPadRepl
//
//  Created by Matthias Zenger on 23/11/2019.
//  Copyright © 2019 Matthias Zenger. All rights reserved.
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
import LispKitTools

public final class LispPadRepl: LispKitRepl {

  public override func setupRootPaths(includeInternalResources: Bool) -> Bool {
    if includeInternalResources {
      if let internalUrl = Bundle.main.resourceURL?
                             .appendingPathComponent("Resources/Assets", isDirectory: true),
         self.context?.fileHandler.isDirectory(atPath: internalUrl.path) ?? false {
        _ = self.context?.fileHandler.prependAssetSearchPath(internalUrl.path)
      }
      if let internalUrl = Bundle.main.resourceURL?
                             .appendingPathComponent("Resources/Libraries", isDirectory: true),
         self.context?.fileHandler.isDirectory(atPath: internalUrl.path) ?? false {
        _ = self.context?.fileHandler.prependLibrarySearchPath(internalUrl.path)
      }
      if let internalUrl = Bundle.main.resourceURL?
                             .appendingPathComponent("Resources", isDirectory: true),
         self.context?.fileHandler.isDirectory(atPath: internalUrl.path) ?? false {
        _ = self.context?.fileHandler.prependSearchPath(internalUrl.path)
      }
    }
    return super.setupRootPaths(includeInternalResources: includeInternalResources)
  }
  
}
