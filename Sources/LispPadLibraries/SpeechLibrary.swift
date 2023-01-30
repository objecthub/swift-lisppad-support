  //
  //  SpeechLibrary.swift
  //  LispPadLibraries
  //
  //  Created by Matthias Zenger on 26/12/2019.
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
  import Cocoa
  import LispKit

  ///
  /// This class implements the LispPad-specific library `(lisppad speech)`.
  ///
  public final class SpeechLibrary: NativeLibrary {
    
    /// Name of the library.
    public override class var name: [String] {
      return ["lisppad", "speech"]
    }
    
    private var currentSpeaker: Speaker?
    private let condition: NSCondition
    private let speakerParam: Procedure
    
    /// Initialization
    public required init(in context: Context) throws {
      self.currentSpeaker = nil
      self.condition = NSCondition()
      if let speaker = Speaker() {
        self.speakerParam = Procedure(.null, .object(speaker))
      } else {
        self.speakerParam = Procedure(.null, .false)
      }
      try super.init(in: context)
    }

    /// Dependencies of the library.
    public override func dependencies() {
    }
    
    /// Declarations of the library.
    public override func declarations() {
      self.define("current-speaker", as: self.speakerParam)
      self.define(Procedure("available-voices", availableVoices))
      self.define(Procedure("voice", voice))
      self.define(Procedure("available-voice?", availableVoice))
      self.define(Procedure("voice-name", voiceName))
      self.define(Procedure("voice-age", voiceAge))
      self.define(Procedure("voice-gender", voiceGender))
      self.define(Procedure("voice-locale", voiceLocale))
      self.define(Procedure("make-speaker", makeSpeaker))
      self.define(Procedure("speaker?", isSpeaker))
      self.define(Procedure("speaker-voice", speakerVoice))
      self.define(Procedure("speaker-rate", speakerRate))
      self.define(Procedure("speaker-volume", speakerVolume))
      self.define(Procedure("speaker-interpret-phonemes", speakerInterpretPhonemes))
      self.define(Procedure("speaker-interpret-numbers", speakerInterpretNumbers))
      self.define(Procedure("speaker-pitch", speakerPitch))
      self.define(Procedure("set-speaker-rate!", setSpeakerRate))
      self.define(Procedure("set-speaker-volume!", setSpeakerVolume))
      self.define(Procedure("set-speaker-interpret-phonemes!", setSpeakerInterpretPhonemes))
      self.define(Procedure("set-speaker-interpret-numbers!", setSpeakerInterpretNumbers))
      self.define(Procedure("set-speaker-pitch!", setSpeakerPitch))
      self.define(Procedure("speak", speak))
      self.define(Procedure("phonemes", phonemes))
    }
    
    public override func initializations() {
    }
    
    private func availableVoices(lang: Expr?, gender: Expr?) throws -> Expr {
      var res = Exprs()
      guard let langFilter = lang else {
        for voice in NSSpeechSynthesizer.availableVoices {
          res.append(.symbol(self.context.symbols.intern(voice.rawValue)))
        }
        return .makeList(res)
      }
      let localeFilter: Locale? = langFilter.isFalse
                                    ? nil : Locale(identifier: try langFilter.asSymbol().identifier)
      var genderFilter: String? = nil
      if let gender = gender {
        switch try gender.asSymbol().identifier {
          case "male":
            genderFilter = "VoiceGenderMale"
          case "female":
            genderFilter = "VoiceGenderFemale"
          default:
            return .null
        }
      }
      for voice in NSSpeechSynthesizer.availableVoices {
        let attribs = NSSpeechSynthesizer.attributes(forVoice: voice)
        if let localeStr = attribs[.localeIdentifier] as? String,
           let genderStr = attribs[.gender] as? String {
          let locale = Locale(identifier: localeStr)
          if localeFilter == nil ||
             ((localeFilter!.languageCode == nil ||
                 localeFilter!.languageCode == locale.languageCode) &&
              (localeFilter!.regionCode == nil ||
                localeFilter!.regionCode == locale.regionCode)) {
            if genderFilter == nil || genderFilter! == genderStr {
              res.append(.symbol(self.context.symbols.intern(voice.rawValue)))
            }
          }
        }
      }
      return .makeList(res)
    }
    
    private func voice(expr: Expr?) -> Expr {
      if let voice = expr {
        switch voice {
          case .string(let str):
            let nameFilter = str.lowercased.trimmingCharacters(in: .whitespaces)
            for voice in NSSpeechSynthesizer.availableVoices {
              if let value = NSSpeechSynthesizer.attributes(forVoice: voice)[.name],
                 let name = value as? String,
                 name.lowercased() == nameFilter {
                return .symbol(self.context.symbols.intern(voice.rawValue))
              }
            }
            return .false
          case .symbol(let sym):
            let idFilter = sym.identifier
            for voice in NSSpeechSynthesizer.availableVoices {
              if voice.rawValue == idFilter {
                return .symbol(self.context.symbols.intern(idFilter))
              }
            }
            return .false
          default:
            return .false
        }
      } else {
        return .symbol(self.context.symbols.intern(NSSpeechSynthesizer.defaultVoice.rawValue))
      }
    }
    
    private func availableVoice(voice: Expr) throws -> Expr {
      if voice.isFalse {
        return .false
      }
      let idFilter = try voice.asSymbol().identifier
      for voice in NSSpeechSynthesizer.availableVoices {
        if voice.rawValue == idFilter {
          return .true
        }
      }
      return .false
    }
    
    private func voiceName(voice: Expr) throws -> Expr {
      if voice.isFalse {
        return .false
      }
      let attribs = NSSpeechSynthesizer.attributes(
                      forVoice: NSSpeechSynthesizer.VoiceName(rawValue:
                                                                try voice.asSymbol().identifier))
      guard let value = attribs[.name],
            let name = value as? String else {
        return .false
      }
      return .makeString(name)
    }
    
    private func voiceAge(voice: Expr) throws -> Expr {
      if voice.isFalse {
        return .false
      }
      let attribs = NSSpeechSynthesizer.attributes(
                      forVoice: NSSpeechSynthesizer.VoiceName(rawValue:
                                                                try voice.asSymbol().identifier))
      guard let value = attribs[.age],
            let age = value as? NSNumber else {
        return .false
      }
      return .fixnum(age.int64Value)
    }
    
    private func voiceGender(voice: Expr) throws -> Expr {
      if voice.isFalse {
        return .false
      }
      let attribs = NSSpeechSynthesizer.attributes(
                      forVoice: NSSpeechSynthesizer.VoiceName(rawValue:
                                                                try voice.asSymbol().identifier))
      guard let value = attribs[.gender],
            let gender = value as? String else {
        return .false
      }
      switch gender {
        case "VoiceGenderMale":
          return .symbol(self.context.symbols.intern("male"))
        case "VoiceGenderFemale":
          return .symbol(self.context.symbols.intern("female"))
        default:
          return .false
      }
    }
    
    private func voiceLocale(voice: Expr) throws -> Expr {
      if voice.isFalse {
        return .false
      }
      let attribs = NSSpeechSynthesizer.attributes(
                      forVoice: NSSpeechSynthesizer.VoiceName(rawValue:
                                                                try voice.asSymbol().identifier))
      guard let value = attribs[.localeIdentifier],
            let locale = value as? String else {
        return .false
      }
      return .symbol(self.context.symbols.intern(Locale(identifier: locale).identifier))
    }
    
    private func makeSpeaker(v: Expr?) throws -> Expr {
      if let speaker = Speaker(voice:
                         (v == nil) || v!.isFalse
                         ? nil
                         : NSSpeechSynthesizer.VoiceName(rawValue: try v!.asSymbol().identifier)) {
        return .object(speaker)
      } else if let expr = v, !expr.isFalse {
        throw RuntimeError.custom("error", "cannot create speaker for voice \(expr)", [])
      } else {
        throw RuntimeError.custom("error", "cannot create speaker for default voice", [])
      }
    }
    
    private func isSpeaker(expr: Expr) throws -> Expr {
      guard case .object(let obj) = expr, obj is Speaker else {
        return .false
      }
      return .true
    }
    
    private func asSpeaker(_ expr: Expr?) throws -> Speaker {
      var expr = expr
      if expr == nil {
        guard let value = self.context.evaluator.getParam(self.speakerParam) else {
          throw RuntimeError.custom("error", "cannot access current speaker object", [])
        }
        expr = value
      }
      guard case .object(let obj) = expr!,
            let speaker = obj as? Speaker else {
        throw RuntimeError.type(expr!, expected: [Speaker.type])
      }
      return speaker
    }
    
    private func speakerVoice(speaker: Expr?) throws -> Expr {
      guard let voiceName = try self.asSpeaker(speaker).synth.voice() else {
        return .false
      }
      return .symbol(self.context.symbols.intern(voiceName.rawValue))
    }
    
    private func speakerRate(speaker: Expr?) throws -> Expr {
      return .flonum(Double(try self.asSpeaker(speaker).synth.rate))
    }
    
    private func speakerVolume(speaker: Expr?) throws -> Expr {
      return .flonum(Double(try self.asSpeaker(speaker).synth.volume))
    }
    
    private func speakerInterpretPhonemes(speaker: Expr?) throws -> Expr {
      guard let mode = try self.asSpeaker(speaker).synth.object(forProperty: .inputMode) as?                                   NSSpeechSynthesizer.SpeechPropertyKey.Mode else {
        return .false
      }
      return .makeBoolean(mode == .phoneme)
    }
    
    private func speakerInterpretNumbers(speaker: Expr?) throws -> Expr {
      guard let mode = try self.asSpeaker(speaker).synth.object(forProperty: .numberMode) as?                                   NSSpeechSynthesizer.SpeechPropertyKey.Mode else {
        return .true
      }
      return .makeBoolean(mode == .normal)
    }
    
    private func speakerPitch(speaker: Expr?) throws -> Expr {
      let synth = try self.asSpeaker(speaker).synth
      guard let base = try synth.object(forProperty: .pitchBase) as? NSNumber,
            let mod = try synth.object(forProperty: .pitchMod) as? NSNumber else {
        return .false
      }
      return .pair(.flonum(base.doubleValue), .flonum(mod.doubleValue))
    }
    
    private func setSpeakerRate(rate: Expr, speaker: Expr?) throws -> Expr {
      try self.asSpeaker(speaker).synth.rate = Float(try rate.asDouble(coerce: true))
      return .void
    }
    
    private func setSpeakerVolume(volume: Expr, speaker: Expr?) throws -> Expr {
      try self.asSpeaker(speaker).synth.volume = Float(try volume.asDouble(coerce: true))
      return .void
    }
    
    private func setSpeakerInterpretPhonemes(phoneme: Expr, speaker: Expr?) throws -> Expr {
      try self.asSpeaker(speaker).synth.setObject(
        phoneme.isFalse ? NSSpeechSynthesizer.SpeechPropertyKey.Mode.text
                        : NSSpeechSynthesizer.SpeechPropertyKey.Mode.phoneme,
        forProperty: .inputMode)
      return .void
    }
    
    private func setSpeakerInterpretNumbers(numbers: Expr, speaker: Expr?) throws -> Expr {
      try self.asSpeaker(speaker).synth.setObject(
        numbers.isFalse ? NSSpeechSynthesizer.SpeechPropertyKey.Mode.literal
                        : NSSpeechSynthesizer.SpeechPropertyKey.Mode.normal,
        forProperty: .numberMode)
      return .void
    }
    
    private func setSpeakerPitch(base: Expr, mod: Expr?, sp: Expr?) throws -> Expr {
      let synth = try self.asSpeaker(sp).synth
      try synth.setObject(NSNumber(floatLiteral: try base.asDouble(coerce: true)),
                          forProperty: .pitchBase)
      if let modulation = mod, !modulation.isFalse {
        try synth.setObject(NSNumber(floatLiteral: try modulation.asDouble(coerce: true)),
                            forProperty: .pitchMod)
      }
      return .void
    }
    
    private func speak(text: Expr, sp: Expr?) throws -> Expr {
      let speaker = try self.asSpeaker(sp)
      self.condition.lock()
      while self.currentSpeaker != nil {
        self.condition.wait()
      }
      self.currentSpeaker = speaker
      self.condition.unlock()
      let res = speaker.speak(text: try text.asString())
      self.condition.lock()
      self.currentSpeaker = nil
      self.condition.unlock()
      return res ? .false : .true
    }
    
    private func phonemes(text: Expr, sp: Expr?) throws -> Expr {
      return .makeString(try self.asSpeaker(sp).synth.phonemes(from: try text.asString()))
    }
    
    public func abortSpeaking() {
      self.currentSpeaker?.abortSpeaking()
    }
  }

  /// Implementation of speaker objects
  class Speaker: NativeObject {
    
    /// Type representing fonts
    public static let type = Type.objectType(Symbol(uninterned: "speaker"))

    let synth: NSSpeechSynthesizer
    let tracker: Tracker
    
    class Tracker: NSObject, NSSpeechSynthesizerDelegate {
      var speaking: Bool
      var failure: Bool
      let condition: NSCondition

      override init() {
        self.speaking = false
        self.failure = false
        self.condition = NSCondition()
      }

      func speechSynthesizer(_ sender: NSSpeechSynthesizer,
                             didEncounterErrorAt: Int,
                             of: String, message: String) {
        self.speakingCompleted(successful: false)
      }

      func speechSynthesizer(_ sender: NSSpeechSynthesizer, didEncounterSyncMessage: String) {
        self.speakingCompleted(successful: false)
      }
      
      func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking: Bool) {
        if didFinishSpeaking {
          self.speakingCompleted(successful: true)
        }
      }
      
      func speakingCompleted(successful: Bool) {
        self.condition.lock()
        self.speaking = false
        if !successful {
          self.failure = true
        }
        self.condition.signal()
        self.condition.unlock()
      }
    }

    init?(voice: NSSpeechSynthesizer.VoiceName? = nil) {
      guard let synth = NSSpeechSynthesizer(voice: voice) else {
        return nil
      }
      self.synth = synth
      self.tracker = Tracker()
      synth.delegate = self.tracker
    }
    
    public override var type: Type {
      return Speaker.type
    }
    
    func speak(text: String) -> Bool {
      self.tracker.condition.lock()
      while self.tracker.speaking {
        self.tracker.condition.wait()
      }
      self.tracker.speaking = true
      self.tracker.failure = false
      self.synth.startSpeaking(text)
      while self.tracker.speaking {
        self.tracker.condition.wait()
      }
      let failed = self.tracker.failure
      self.tracker.condition.unlock()
      return failed
    }

    func speakAsync(text: String) {
      self.tracker.condition.lock()
      while self.tracker.speaking {
        self.tracker.condition.wait()
      }
      self.tracker.speaking = true
      self.synth.startSpeaking(text)
      self.tracker.condition.unlock()
    }
    
    func abortSpeaking() {
      self.tracker.condition.lock()
      self.synth.stopSpeaking()
      self.tracker.speaking = false
      self.tracker.failure = true
      self.tracker.condition.signal()
      self.tracker.condition.unlock()
    }
    
    var isSpeaking: Bool {
      return self.tracker.speaking
    }
  }
