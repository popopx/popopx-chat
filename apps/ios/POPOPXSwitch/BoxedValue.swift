//
//  BoxedValue.swift
//  POPOPXSwitch
//
//  Created by Stanislav Dmitrenko on 02.12.2024.
//  Copyright © 2025 POPOPX. All rights reserved.
//

import Foundation

public class BoxedValue<T: Hashable>: Equatable, Hashable {
    public static func == (lhs: BoxedValue<T>, rhs: BoxedValue<T>) -> Bool {
        lhs.boxedValue == rhs.boxedValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(boxedValue)
    }

    public var boxedValue : T
    public init(_ value: T) {
        self.boxedValue = value
    }
}
