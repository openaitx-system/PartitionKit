//
//  VPartition.swift
//
//
//  Created by Kieran Brown on 10/26/19.
//

import SwiftUI

/// # Vertical Partition
///
///  Used to create resizable views that share a total height,
///  Takes 3 generic arguments to prevent users from needing to wrap content views within an  `AnyView`
///
///   - note
///   the syntax looks something like this, So if closures are still kind of new to you just think that you are sending a letter(`View`) to somebody  and it needs an Envelope(`{}`) to get there.
///
///   ```
///   VPart(top: {
///       Rectangle()
///   }, bottom: {
///       Circle()
///  }) {
///     Capsule()
///  }
///  ```
///
@MainActor public struct VPart<Top, Bottom, Handle> where Top: View, Bottom: View, Handle: View {
    public var top: Top
    public var bottom: Bottom
    public var handle: Handle
    
    /// Amount of time it takes before a gesture is recognized as a longPress, the precursor to the drag.
    var minimumLongPressDuration = 0.05
    var handleSize: CGSize = CGSize(width: 75, height: 10)
    public var pctSplit: CGFloat = 0.5
    var paddingFactor: CGFloat = 0.9
    
    @GestureState private var dragState = DragState.inactive
    @State var viewState = CGSize.zero

    @Environment(\._partitionHandleStyle) private var handleStyle
    @Environment(\._partitionHandleSize) private var environmentHandleSize
    @Environment(\._partitionLongPressDuration) private var environmentLongPressDuration

    /// The effective handle size, preferring the environment value when set.
    var effectiveHandleSize: CGSize { environmentHandleSize ?? handleSize }
    /// The effective long press duration, preferring the environment value when set.
    var effectiveLongPressDuration: Double { environmentLongPressDuration ?? minimumLongPressDuration }

    // The maximum offset so that neither pane has a negative height.
    // top height = paddingFactor * pctSplit * height + offset  >= 0  →  offset >= -paddingFactor * pctSplit * height
    // bottom height = paddingFactor * (1-pctSplit) * height - offset >= 0  →  offset <= paddingFactor * (1-pctSplit) * height
    func clampedOffset(_ offset: CGFloat, in height: CGFloat) -> CGFloat {
        let minOffset = -paddingFactor * pctSplit * height
        let maxOffset =  paddingFactor * (1 - pctSplit) * height
        return min(max(offset, minOffset), maxOffset)
    }

    // A bit of a convienence so I dont have to write this again and again.
    var currentOffset: CGFloat {
        viewState.height + dragState.translation.height
    }

    /// The public drag state derived from the internal gesture state.
    var publicDragState: PartitionDragState {
        switch dragState {
        case .inactive: return .inactive
        case .pressing: return .pressing
        case .dragging: return .dragging
        }
    }
    
    /// Creates the `Handle` and adds the drag gesture to it.
    func generateHandle(in height: CGFloat) -> some View {
        let longPressDrag = LongPressGesture(minimumDuration: effectiveLongPressDuration)
            .sequenced(before: DragGesture())
            .updating($dragState) { value, state, transaction in
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
                let proposed = viewState.height + drag.translation.height
                viewState.height = clampedOffset(proposed, in: height)
                viewState.width = 0
            }

        let configuration = PartitionHandleStyleConfiguration(
            handle: AnyView(handle),
            dragState: publicDragState
        )

        return handleStyle.makeBody(configuration: configuration)
            .frame(width: effectiveHandleSize.width, height: effectiveHandleSize.height, alignment: .center)
            .offset(x: 0, y: clampedOffset(currentOffset, in: height))
            .gesture(longPressDrag)
            .environment(\.partitionDragState, publicDragState)
    }

    public var body: some View {
        GeometryReader { (proxy: GeometryProxy) in
            VStack {
                let height = proxy.frame(in: .local).height
                let offset = clampedOffset(currentOffset, in: height)

                top
                    .frame(height: paddingFactor * pctSplit * height + offset)
                    .environment(\.partitionDragState, publicDragState)

                Divider()

                bottom
                    .frame(height: paddingFactor * (1 - pctSplit) * height - offset)
                    .environment(\.partitionDragState, publicDragState)
            }
            .overlay(generateHandle(in: proxy.frame(in: .local).height), alignment: .center)
        }
    }
}

// MARK: - Init

extension VPart: View where Top: View, Bottom: View, Handle: View {
    
    /// # Vertical Partition With Custom Handle
    ///
    /// - parameters:
    ///    - top: Any type of View within a closure.
    ///    - bottom: Any type of View within a closure
    ///    - handle: Any type of View within a closure. The `Handle` is the view that the user will use to drag and resize the partitions.
    @inlinable public init(@ViewBuilder top: () -> Top, @ViewBuilder bottom: () -> Bottom, @ViewBuilder handle: () -> Handle) {
        self.top = top()
        self.bottom = bottom()
        self.handle = handle()
    }
    
    /// # Vertical Partition With Custom Handle
    ///
    /// - parameters:
    ///    - pctSplit: The ratio of space the top takes up compared to the bottom. Use between 0 and 1.
    ///    - top: Any type of View within a closure.
    ///    - bottom: Any type of View within a closure
    ///    - handle: Any type of View within a closure. The `Handle` is the view that the user will use to drag and resize the partitions.
    @inlinable public init(pctSplit: CGFloat, @ViewBuilder top: () -> Top, @ViewBuilder bottom: () -> Bottom, @ViewBuilder handle: () -> Handle) {
        self.pctSplit = pctSplit
        self.top = top()
        self.bottom = bottom()
        self.handle = handle()
    }
    
}

extension VPart where Top: View, Bottom: View, Handle == Capsule {
    
    /// # Vertical Partition With Default Handle
    ///
    /// - parameters:
    ///    - top: Any type of View within a closure.
    ///    - bottom: Any type of View within a closure
    ///
    /// - note
    ///  The `Handle` used here is a `Capsule` that is wider than it is tall.
    @inlinable public init(@ViewBuilder top: () -> Top, @ViewBuilder bottom: () -> Bottom) {
        self.top = top()
        self.bottom = bottom()
        self.handle = Capsule()
    }
    
    /// # Vertical Partition With Default Handle
    ///
    /// - parameters:
    ///    - pctSplit: The ratio of space the top takes up compared to the bottom. Use between 0 and 1.
    ///    - top: Any type of View within a closure.
    ///    - bottom: Any type of View within a closure
    ///
    /// - note
    ///  The `Handle` used here is a `Capsule` that is wider than it is tall.
    @inlinable public init(pctSplit: CGFloat, @ViewBuilder top: () -> Top, @ViewBuilder bottom: () -> Bottom) {
        self.pctSplit = pctSplit
        self.top = top()
        self.bottom = bottom()
        self.handle = Capsule()
    }
    
}
