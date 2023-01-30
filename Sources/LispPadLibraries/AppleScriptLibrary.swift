//
//  AppleScriptLibrary.swift
//  LispPadLibraries
//
//  Created by Matthias Zenger on 22/05/2020.
//  Copyright © 2020 Matthias Zenger. All rights reserved.
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
import Carbon
import LispKit

///
/// This class implements the LispPad-specific library `(lisppad applescript)`.
///
public final class AppleScriptLibrary: NativeLibrary {

  /// Name of the library.
  public override class var name: [String] {
    return ["lisppad", "applescript"]
  }

  /// Dependencies of the library.
  public override func dependencies() {
    self.`import`(from: ["lispkit", "core"], "define", "lambda", "apply")
  }

  /// Declarations of the library.
  public override func declarations() {
    self.define(Procedure("applescript", applescript))
    self.define(Procedure("applescript?", isApplescript))
    self.define(Procedure("applescript-path", applescriptPath))
    self.define(Procedure("execute-applescript", executeApplescript))
    self.define(Procedure("apply-applescript-proc", applyApplescriptProc))
    self.define("applescript-proc", via:
    "(define (applescript-proc script name)",
    "  (lambda args (apply apply-applescript-proc script name args)))")
  }

  public override func initializations() {
  }

  private var currentScripts: Set<NativeAppleScript> = []

  private func applescript(path: Expr) throws -> Expr {
    let filename = try path.asString()
    let dirs = NSSearchPathForDirectoriesInDomains(.applicationScriptsDirectory,
                                                   .userDomainMask,
                                                   true)
    for dir in dirs {
      let url = URL(fileURLWithPath: filename,
                    isDirectory: false,
                    relativeTo: URL(fileURLWithPath: dir, isDirectory: true))
      if self.context.fileHandler.isFile(atPath: url.absoluteURL.path) {
        return .object(NativeAppleScript(url: url))
      }
    }
    let url = URL(fileURLWithPath: filename, isDirectory: false)
    guard self.context.fileHandler.isFile(atPath: url.absoluteURL.path) else {
      throw RuntimeError.eval(.unknownFile, path)
    }
    return .object(NativeAppleScript(url: url))
  }

  private func isApplescript(expr: Expr) throws -> Expr {
    guard case .object(let obj) = expr, obj is NativeAppleScript else {
      return .false
    }
    return .true
  }

  private func applescriptPath(script: Expr) throws -> Expr {
    return .makeString(try self.asScript(script).path)
  }

  private func applescriptProc(script: Expr, name: Expr) throws -> Expr {
    return .void
  }

  private func executeApplescript(script: Expr) throws -> Expr {
    let script = try self.asScript(script)
    self.currentScripts.insert(script)
    defer {
      self.currentScripts.remove(script)
    }
    try script.execute()
    return .void
  }

  private func applyApplescriptProc(script: Expr, name: Expr, args: Arguments) throws -> Expr {
    let script = try self.asScript(script)
    self.currentScripts.insert(script)
    defer {
      self.currentScripts.remove(script)
    }
    return try script.execute(name: try name.asString(), args: args)
  }

  private func asScript(_ expr: Expr) throws -> NativeAppleScript {
    guard case .object(let obj) = expr,
          let script = obj as? NativeAppleScript else {
      throw RuntimeError.type(expr, expected: [NativeAppleScript.type])
    }
    return script
  }

  public func abortExecuting() {
    for script in self.currentScripts {
      script.abortExecution()
    }
    self.currentScripts.removeAll()
  }
}

final class NativeAppleScript: NativeObject {

  /// Type representing apple scripts
  public static let type = Type.objectType(Symbol(uninterned: "applescript"))

  /// Calendar used for handling dates
  private static let calendar = Calendar(identifier: Calendar.Identifier.gregorian)

  private final class Computation {
    let condition: NSCondition
    var failure: Error?
    var result: Expr?

    init() {
      self.condition = NSCondition()
      self.failure = nil
      self.result = nil
    }

    var isExecuting: Bool {
      return self.failure == nil && self.result == nil
    }
  }

  private let url: URL
  private var computation: Computation? = nil

  init(url: URL) {
    self.url = url
    self.computation = nil
  }

  public override var type: Type {
    return NativeAppleScript.type
  }

  public override var string: String {
    return "#<applescript \(self.url.path)>"
  }

  private func event(from expr: Expr) throws -> NSAppleEventDescriptor {
    switch expr {
      case .void:
        return NSAppleEventDescriptor.null()
      case .false:
        return NSAppleEventDescriptor(boolean: false)
      case .true:
        return NSAppleEventDescriptor(boolean: true)
      case .null:
        return NSAppleEventDescriptor.list()
      case .pair(let car, let cdr):
        var next = cdr
        let res = NSAppleEventDescriptor.list()
        res.insert(try self.event(from: car), at: 1)
        var i = 1
        while case .pair(let head, let tail) = next {
          i += 1
          res.insert(try self.event(from: head), at: i)
          next = tail
        }
        guard case .null = next else {
          throw RuntimeError.custom("error", "cannot convert expression", [])
        }
        return res
      case .string(let str):
        return NSAppleEventDescriptor(string: str as String)
      case .object(let obj):
        if let dateTime = obj as? NativeDateTime,
           let date = dateTime.value.date {
          return NSAppleEventDescriptor(date: date)
        } else {
          throw RuntimeError.custom("error", "cannot convert expression", [])
        }
      case .flonum(let num):
        return NSAppleEventDescriptor(double: num)
      case .fixnum(let num):
        if let x = Int32(exactly: num) {
          return NSAppleEventDescriptor(int32: x)
        } else {
          fallthrough
        }
      default:
        throw RuntimeError.custom("error", "cannot convert expression", [])
    }
  }

  private func expr(from event: NSAppleEventDescriptor) -> Expr {
    switch event.descriptorType {
      case 0x6e756c6c:  // type of `null`
        return .void
      case typeTrue:
        return .true
      case typeFalse:
        return .false
      case typeBoolean:
        return .makeBoolean(event.booleanValue)
      case cAEList:
        var res = Expr.null
        var i = event.numberOfItems
        while i > 0 {
          if let elem = event.atIndex(i) {
            res = .pair(self.expr(from: elem), res)
            i -= 1
          }
        }
        return res
      case typeUnicodeText, typeUTF8Text:
        if let str = event.stringValue {
          return .makeString(str)
        } else {
          return .undef
        }
      case typeFileURL:
        if let url = event.fileURLValue {
          return .makeString(url.absoluteURL.path)
        } else {
          return .undef
        }
      case typeLongDateTime:
        if let date = event.dateValue {
          return .object(NativeDateTime(NativeAppleScript.calendar.dateComponents(
                                          in: TimeZone.current, from: date)))
        } else {
          return .undef
        }
      case typeSInt32, typeSInt16, typeUInt32, typeUInt16:
        return .fixnum(Int64(event.int32Value))
      case typeIEEE64BitFloatingPoint, typeIEEE32BitFloatingPoint:
        return .flonum(event.doubleValue)
      default:
        // Swift.print("cannot convert \(event) of type \(String(event.descriptorType, radix: 16))")
        return .undef
    }
  }

  func execute(async: Bool = false) throws {
    let script = try NSUserScriptTask(url: self.url)
    guard !async else {
      script.execute(completionHandler: nil)
      return
    }
    let computation = Computation()
    self.computation = computation
    computation.condition.lock()
    defer {
      computation.condition.unlock()
      self.computation = nil
    }
    script.execute { error in
      computation.condition.lock()
      computation.failure = error
      computation.result = .void
      computation.condition.signal()
      computation.condition.unlock()
    }
    while computation.isExecuting {
      computation.condition.wait()
    }
    if let error = computation.failure {
      throw error
    }
  }

  func execute(name: String, args: Arguments) throws -> Expr {
    let script = try NSUserAppleScriptTask(url: self.url)
    let event = NSAppleEventDescriptor(eventClass: AEEventClass(kASAppleScriptSuite),
                                       eventID: AEEventID(kASSubroutineEvent),
                                       targetDescriptor: nil,
                                       returnID: AEReturnID(kAutoGenerateReturnID),
                                       transactionID: AETransactionID(kAnyTransactionID))
    event.setDescriptor(NSAppleEventDescriptor(string: name),
                        forKeyword: AEKeyword(keyASSubroutineName))
    if args.count > 0 {
      let parameters = NSAppleEventDescriptor.list()
      var i = 0
      for arg in args {
        i += 1
        guard let param = try? self.event(from: arg) else {
          throw RuntimeError.custom("error",
                  "cannot call applescript procedure \(name) with argument \(arg)", [])
        }
        parameters.insert(param, at: i)
      }
      event.setDescriptor(parameters, forKeyword: AEKeyword(keyDirectObject))
    }
    let computation = Computation()
    self.computation = computation
    computation.condition.lock()
    defer {
      computation.condition.unlock()
      self.computation = nil
    }
    script.execute(withAppleEvent: event) { event, error in
      computation.condition.lock()
      computation.failure = error
      if let res = event, error == nil {
        computation.result = self.expr(from: res)
      } else {
        computation.result = nil
      }
      computation.condition.signal()
      computation.condition.unlock()
    }
    while computation.isExecuting {
      computation.condition.wait()
    }
    if let error = computation.failure {
      throw error
    }
    return computation.result ?? .void
  }

  func abortExecution() {
    guard let computation = self.computation else {
      return
    }
    computation.condition.lock()
    if computation.isExecuting {
      computation.failure = RuntimeError.abortion()
      computation.result = nil
      computation.condition.signal()
    }
    computation.condition.unlock()
  }

  var path: String {
    return self.url.absoluteURL.path
  }
}
