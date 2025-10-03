//
//  File.swift
//
//
//  Created by Jordan Howlett on 6/20/24.
//

import Foundation

@available(iOS 16.0, macOS 13.0, *)
extension Duration {
    var inMilliseconds: Double {
        let v = components
        return Double(v.seconds) * 1000 + Double(v.attoseconds) * 1e-15
    }
}
