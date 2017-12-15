//
//  Extensions.swift
//  ARniegeddon
//
//  Created by Diana Jung on 12/14/17.
//  Copyright © 2017 Ray Wenderlich. All rights reserved.
//

import Foundation
public extension Float {

  // Returns a random floating point number between 0.0 and 1.0, inclusive.

  public static var random:Float {
    get {
      return Float(arc4random()) / 0xFFFFFFFF
    }
  }
  /*
   Create a random num Float

   - parameter min: Float
   - parameter max: Float

   - returns: Float
   */
  public static func random(min: Float, max: Float) -> Float {
    return Float.random * (max - min) + min
  }
}
