//
//  PartitionConfiguration.swift
//
//
//  Created by Kieran Brown on 3/11/26.
//

import SwiftUI

// MARK: - Handle Size Environment Key

struct PartitionHandleSizeKey: EnvironmentKey {
    static let defaultValue: CGSize? = nil
}

extension EnvironmentValues {
    /// Overrides the handle size for all partitions within the view hierarchy.
    ///
    /// When `nil` (the default), each partition uses its own built-in default size.
    var _partitionHandleSize: CGSize? {
        get { self[PartitionHandleSizeKey.self] }
        set { self[PartitionHandleSizeKey.self] = newValue }
    }
}

// MARK: - Long Press Duration Environment Key

struct PartitionLongPressDurationKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    /// Overrides the minimum long-press duration before a drag begins for all
    /// partitions within the view hierarchy.
    ///
    /// When `nil` (the default), each partition uses its own built-in default (0.05 s).
    var _partitionLongPressDuration: Double? {
        get { self[PartitionLongPressDurationKey.self] }
        set { self[PartitionLongPressDurationKey.self] = newValue }
    }
}

// MARK: - View Modifiers

extension View {
    /// Sets the drag-handle size for all partitions within this view hierarchy.
    ///
    /// Use this modifier to give every `VPart`, `HPart`, or `GridPart` inside the
    /// modified hierarchy a uniform handle size without changing each one individually.
    ///
    /// ```swift
    /// VPart(top: { TopView() }, bottom: { BottomView() })
    ///     .partitionHandleSize(CGSize(width: 100, height: 16))
    /// ```
    public func partitionHandleSize(_ size: CGSize) -> some View {
        environment(\._partitionHandleSize, size)
    }

    /// Sets the minimum long-press duration before dragging begins for all
    /// partitions within this view hierarchy.
    ///
    /// Decreasing this value makes handles feel more responsive; increasing it
    /// reduces accidental drags.
    ///
    /// ```swift
    /// GridPart(topLeft: { A() }, topRight: { B() }, bottomLeft: { C() }, bottomRight: { D() })
    ///     .partitionLongPressDuration(0.0)   // drag starts immediately
    /// ```
    public func partitionLongPressDuration(_ duration: Double) -> some View {
        environment(\._partitionLongPressDuration, duration)
    }
}
