//
//  PartitionDragState.swift
//
//
//  Created by Kieran Brown on 3/11/26.
//

import SwiftUI

// MARK: - Public Drag State

/// Describes the current interaction state of a partition handle.
///
/// Use this type together with the `\.partitionDragState` environment value to
/// read the drag state from inside a handle or content view and adjust its
/// appearance accordingly.
///
/// ```swift
/// struct MyHandle: View {
///     @Environment(\.partitionDragState) var dragState
///
///     var body: some View {
///         Capsule()
///             .fill(dragState == .dragging ? Color.accentColor : Color.secondary)
///             .scaleEffect(dragState.isActive ? 1.2 : 1.0)
///             .animation(.spring(), value: dragState)
///     }
/// }
/// ```
public enum PartitionDragState: Equatable, Sendable {
    /// No gesture is active.
    case inactive
    /// A long press has been recognized but the drag has not begun.
    case pressing
    /// The handle is actively being dragged.
    case dragging

    /// Whether any gesture phase is active (pressing or dragging).
    public var isActive: Bool {
        self != .inactive
    }

    /// Whether the handle is being dragged.
    public var isDragging: Bool {
        self == .dragging
    }
}

// MARK: - Environment Key

struct PartitionDragStateKey: EnvironmentKey {
    static let defaultValue: PartitionDragState = .inactive
}

extension EnvironmentValues {
    /// The current drag state of the nearest enclosing partition handle.
    ///
    /// Read this value inside a handle view or any content view nested inside
    /// a partition to react to the handle interaction:
    ///
    /// ```swift
    /// @Environment(\.partitionDragState) var dragState
    /// ```
    public var partitionDragState: PartitionDragState {
        get { self[PartitionDragStateKey.self] }
        set { self[PartitionDragStateKey.self] = newValue }
    }
}

// MARK: - PartitionHandleStyle Protocol

/// A type that defines the appearance and behavior of a partition handle.
///
/// Conform to this protocol to create reusable handle styles, then apply them
/// with the `.partitionHandleStyle(_:)` modifier.
///
/// ```swift
/// struct ScalingHandleStyle: PartitionHandleStyle {
///     func makeBody(configuration: Configuration) -> some View {
///         configuration.handle
///             .scaleEffect(configuration.dragState.isActive ? 1.3 : 1.0)
///             .animation(.spring(), value: configuration.dragState)
///     }
/// }
///
/// VPart(top: { ... }, bottom: { ... })
///     .partitionHandleStyle(ScalingHandleStyle())
/// ```
@MainActor
public protocol PartitionHandleStyle {
    /// The type of view that represents the styled handle.
    associatedtype Body: View

    /// A view built from the handle and its current drag configuration.
    @ViewBuilder @MainActor func makeBody(configuration: Configuration) -> Body

    /// The configuration passed to `makeBody(configuration:)`.
    typealias Configuration = PartitionHandleStyleConfiguration
}

/// The configuration for a `PartitionHandleStyle`.
public struct PartitionHandleStyleConfiguration {
    /// The unstyled handle view.
    public let handle: AnyView
    /// The current drag interaction state of the handle.
    public let dragState: PartitionDragState
}

// MARK: - Built-in Styles

/// The default partition handle style.
///
/// This style shows a white overlay circle stroke when dragging, matching the
/// original library appearance.
public struct DefaultPartitionHandleStyle: PartitionHandleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.handle
            .overlay(
                configuration.dragState.isDragging
                    ? AnyView(Circle().stroke(Color.white, lineWidth: 2))
                    : AnyView(EmptyView())
            )
            .foregroundColor(.white)
    }
}

/// A handle style that scales the handle up while it is active.
///
/// Apply this style using `.partitionHandleStyle(ScaledPartitionHandleStyle())`.
public struct ScaledPartitionHandleStyle: PartitionHandleStyle {
    /// The scale factor applied while the handle is active. Defaults to `1.2`.
    public var activeScale: CGFloat

    public init(activeScale: CGFloat = 1.2) {
        self.activeScale = activeScale
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.handle
            .foregroundColor(.white)
            .scaleEffect(configuration.dragState.isActive ? activeScale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.dragState)
    }
}

// MARK: - Environment Key for the Style

// Stored as a type-erased wrapper so it can live in the environment.
struct AnyPartitionHandleStyle: PartitionHandleStyle {
    private let _makeBody: @MainActor (Configuration) -> AnyView

    @MainActor init<S: PartitionHandleStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @MainActor func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct PartitionHandleStyleKey: EnvironmentKey {
    static let defaultValue: AnyPartitionHandleStyle = {
        MainActor.assumeIsolated {
            AnyPartitionHandleStyle(DefaultPartitionHandleStyle())
        }
    }()
}

extension EnvironmentValues {
    var _partitionHandleStyle: AnyPartitionHandleStyle {
        get { self[PartitionHandleStyleKey.self] }
        set { self[PartitionHandleStyleKey.self] = newValue }
    }
}

// MARK: - View Modifier

extension View {
    /// Sets the style used to render partition handles within this view.
    ///
    /// Use this modifier to apply a consistent look to every handle inside the
    /// modified view hierarchy. The style receives the handle view and the
    /// current `PartitionDragState` each time the gesture phase changes.
    ///
    /// ```swift
    /// VPart(top: { RedView() }, bottom: { BlueView() })
    ///     .partitionHandleStyle(ScaledPartitionHandleStyle())
    /// ```
    public func partitionHandleStyle<S: PartitionHandleStyle>(_ style: S) -> some View {
        environment(\._partitionHandleStyle, AnyPartitionHandleStyle(style))
    }
}
