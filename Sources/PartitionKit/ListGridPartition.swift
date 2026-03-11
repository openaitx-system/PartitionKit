//
//  ListGridPartition.swift
//
//
//  Created by Kieran Brown on 3/11/26.
//

import SwiftUI

// MARK: - ListGridPart

/// # List Grid Partition
///
/// A scrollable list of resizable rows. Each row is sized proportionally and can
/// be resized by dragging the handle between adjacent rows. Supply any
/// `RandomAccessCollection` whose elements conform to `Identifiable`.
///
/// ```swift
/// struct Item: Identifiable {
///     let id: Int
///     let color: Color
/// }
///
/// let items = (0..<4).map { Item(id: $0, color: [.red, .blue, .green, .orange][$0]) }
///
/// ListGridPart(items) { item in
///     RoundedRectangle(cornerRadius: 12)
///         .fill(item.color)
///         .padding(4)
/// }
/// ```
///
/// Each divider handle defaults to a `Capsule`. Pass a custom handle view using
/// the `handle:` parameter.
@MainActor public struct ListGridPart<Data, RowContent, Handle>: View
    where Data: RandomAccessCollection,
          Data.Element: Identifiable,
          RowContent: View,
          Handle: View
{
    // MARK: - Stored Properties

    private let data: Data
    private let rowContent: (Data.Element) -> RowContent
    private let handle: () -> Handle

    /// The initial fraction of total height each row occupies (uniform by default).
    private let initialFractions: [CGFloat]

    /// Per-divider vertical offsets, one fewer than the number of rows.
    /// `offsets[i]` shifts the boundary between row `i` and row `i+1`.
    @State private var offsets: [CGFloat]

    @Environment(\._partitionHandleStyle) private var handleStyle
    @Environment(\._partitionHandleSize) private var environmentHandleSize
    @Environment(\._partitionLongPressDuration) private var environmentLongPressDuration

    var effectiveLongPressDuration: Double { environmentLongPressDuration ?? 0.05 }
    var defaultHandleSize: CGSize { CGSize(width: 75, height: 10) }
    var effectiveHandleSize: CGSize { environmentHandleSize ?? defaultHandleSize }

    // MARK: - Init (custom handle)

    /// Creates a `ListGridPart` with a custom handle view between rows.
    ///
    /// - Parameters:
    ///   - data: The collection of `Identifiable` items to display.
    ///   - handle: A view builder that produces the drag handle placed between rows.
    ///   - rowContent: A view builder mapping each element to its row view.
    public init(
        _ data: Data,
        @ViewBuilder handle: @escaping () -> Handle,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.data = data
        self.rowContent = rowContent
        self.handle = handle
        let count = data.count
        let fraction: CGFloat = count > 0 ? 1.0 / CGFloat(count) : 1.0
        self.initialFractions = Array(repeating: fraction, count: count)
        self._offsets = State(initialValue: Array(repeating: 0, count: max(count - 1, 0)))
    }

    /// Creates a `ListGridPart` with a custom handle view between rows and
    /// explicit initial row fractions.
    ///
    /// - Parameters:
    ///   - data: The collection of `Identifiable` items to display.
    ///   - fractions: Initial fractional heights for each row (should sum to 1).
    ///     If the count does not match `data.count` the values are ignored and
    ///     uniform fractions are used instead.
    ///   - handle: A view builder that produces the drag handle placed between rows.
    ///   - rowContent: A view builder mapping each element to its row view.
    public init(
        _ data: Data,
        fractions: [CGFloat],
        @ViewBuilder handle: @escaping () -> Handle,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.data = data
        self.rowContent = rowContent
        self.handle = handle
        let count = data.count
        if fractions.count == count {
            self.initialFractions = fractions
        } else {
            let fraction: CGFloat = count > 0 ? 1.0 / CGFloat(count) : 1.0
            self.initialFractions = Array(repeating: fraction, count: count)
        }
        self._offsets = State(initialValue: Array(repeating: 0, count: max(count - 1, 0)))
    }

    // MARK: - Height Calculation

    /// Computes the height of each row given the total available height and the
    /// current divider offsets.
    ///
    /// The offset for divider `i` shifts the boundary between row `i` and `i+1`.
    /// Each offset is clamped so neither adjacent row reaches zero height.
    private func rowHeights(totalHeight: CGFloat) -> [CGFloat] {
        let n = data.count
        guard n > 0 else { return [] }

        // Base heights before any offset adjustments
        var heights = initialFractions.map { $0 * totalHeight }

        for i in 0 ..< offsets.count {
            // The raw offset for divider i
            let raw = offsets[i]
            // Clamp so row i and row i+1 both stay >= 0
            let clampedDelta = min(max(raw, -heights[i]), heights[i + 1])
            let actual = clampedDelta
            heights[i]     += actual
            heights[i + 1] -= actual
        }

        return heights.map { max($0, 0) }
    }

    // MARK: - Drag Gesture for a divider

    @State private var dragStates: [DragState] = []

    // MARK: - Body

    public var body: some View {
        GeometryReader { proxy in
            let totalHeight = proxy.frame(in: .local).height
            let heights = rowHeights(totalHeight: totalHeight)
            let items = Array(data)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        rowContent(item)
                            .frame(height: heights.indices.contains(index) ? heights[index] : nil)
                            .environment(\.partitionDragState, .inactive)

                        // Place a handle after every row except the last
                        if index < items.count - 1 {
                            dividerHandle(at: index, totalHeight: totalHeight, heights: heights)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Divider Handle

    @ViewBuilder
    private func dividerHandle(at index: Int, totalHeight: CGFloat, heights: [CGFloat]) -> some View {
        DividerHandleView(
            index: index,
            totalHeight: totalHeight,
            heights: heights,
            initialFractions: initialFractions,
            offsets: $offsets,
            handle: handle,
            handleStyle: handleStyle,
            effectiveHandleSize: effectiveHandleSize,
            effectiveLongPressDuration: effectiveLongPressDuration
        )
    }
}

// MARK: - Default Handle (Capsule) Convenience Init

extension ListGridPart where Handle == Capsule {
    /// Creates a `ListGridPart` using a `Capsule` as the default drag handle.
    public init(
        _ data: Data,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.init(data, handle: { Capsule() }, rowContent: rowContent)
    }

    /// Creates a `ListGridPart` with explicit initial row fractions and a default `Capsule` handle.
    public init(
        _ data: Data,
        fractions: [CGFloat],
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.init(data, fractions: fractions, handle: { Capsule() }, rowContent: rowContent)
    }
}

// MARK: - DividerHandleView (internal helper)

/// An individual draggable divider between two rows.
@MainActor
private struct DividerHandleView<Handle: View>: View {
    let index: Int
    let totalHeight: CGFloat
    let heights: [CGFloat]
    let initialFractions: [CGFloat]
    @Binding var offsets: [CGFloat]
    let handle: () -> Handle
    let handleStyle: AnyPartitionHandleStyle
    let effectiveHandleSize: CGSize
    let effectiveLongPressDuration: Double

    @GestureState private var dragState = DragState.inactive

    private var publicDragState: PartitionDragState {
        switch dragState {
        case .inactive: return .inactive
        case .pressing: return .pressing
        case .dragging: return .dragging
        }
    }

    /// Maximum drag delta so neither neighbour reaches zero height.
    private func clampDelta(_ delta: CGFloat) -> CGFloat {
        let maxDown =  heights[index + 1]
        let maxUp   = -heights[index]
        return min(max(delta, maxUp), maxDown)
    }

    var body: some View {
        let dragGesture = LongPressGesture(minimumDuration: effectiveLongPressDuration)
            .sequenced(before: DragGesture())
            .updating($dragState) { value, state, _ in
                switch value {
                case .first(true):
                    state = .pressing
                case .second(true, let drag):
                    state = .dragging(translation: drag?.translation ?? .zero)
                default:
                    state = .inactive
                }
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value else { return }
                offsets[index] += clampDelta(drag.translation.height)
            }

        let configuration = PartitionHandleStyleConfiguration(
            handle: AnyView(handle()),
            dragState: publicDragState
        )

        return handleStyle.makeBody(configuration: configuration)
            .frame(width: effectiveHandleSize.width, height: effectiveHandleSize.height)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .environment(\.partitionDragState, publicDragState)
    }
}
