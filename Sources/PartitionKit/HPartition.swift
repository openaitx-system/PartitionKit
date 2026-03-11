//
//  HPartition.swift
//
//
//  Created by Kieran Brown on 10/26/19.
//

import SwiftUI

/// # Horizontal Partition
///
///  Used to create resizable views that share a total width,
///  Takes 3 generic arguments to prevent users from needing to wrap content views within an  `AnyView`
///
///   - note
///   the syntax looks something like this, So if closures are still kind of new to you just think that you are sending a letter(`View`) to somebody  and it needs an Envelope(`{}`) to get there.
///
///   ```
///   HPart(left: {
///       Rectangle()
///   }, right: {
///       Circle()
///  }) {
///     Capsule()
///  }
///  ```
///
@MainActor public struct HPart<Left, Right, Handle> where Left: View, Right: View, Handle: View {
    public var left: Left
    public var right: Right
    public var handle: Handle
    
    /// Amount of time it takes before a gesture is recognized as a longPress, the precursor to the drag.
    var minimumLongPressDuration = 0.05
    var handleSize: CGSize = CGSize(width: 10, height: 75)
    public var pctSplit: CGFloat = 0.5
    var paddingFactor: CGFloat = 0.9
    
    // dragState and viewState are also taken directly froms Apples "Composing SwiftUI Gestures"
    @GestureState var dragState = DragState.inactive
    @State var viewState = CGSize.zero
    
    @Environment(\._partitionHandleStyle) private var handleStyle
    @Environment(\._partitionHandleSize) private var environmentHandleSize
    @Environment(\._partitionLongPressDuration) private var environmentLongPressDuration

    /// The effective handle size, preferring the environment value when set.
    var effectiveHandleSize: CGSize { environmentHandleSize ?? handleSize }
    /// The effective long press duration, preferring the environment value when set.
    var effectiveLongPressDuration: Double { environmentLongPressDuration ?? minimumLongPressDuration }

    // The maximum offset so that neither pane has a negative width.
    // left width  = paddingFactor * pctSplit * width + offset >= 0  →  offset >= -paddingFactor * pctSplit * width
    // right width = paddingFactor * (1-pctSplit) * width - offset >= 0  →  offset <= paddingFactor * (1-pctSplit) * width
    func clampedOffset(_ offset: CGFloat, in width: CGFloat) -> CGFloat {
        let minOffset = -paddingFactor * pctSplit * width
        let maxOffset =  paddingFactor * (1 - pctSplit) * width
        return min(max(offset, minOffset), maxOffset)
    }

    // A bit of a convienence so I dont have to write this again and again.
    var currentOffset: CGFloat {
        viewState.width + dragState.translation.width
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
    func generateHandle(in width: CGFloat) -> some View {
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
                let proposed = viewState.width + drag.translation.width
                viewState.width = clampedOffset(proposed, in: width)
                viewState.height = 0
            }

        let configuration = PartitionHandleStyleConfiguration(
            handle: AnyView(handle),
            dragState: publicDragState
        )

        return handleStyle.makeBody(configuration: configuration)
            .frame(width: effectiveHandleSize.width, height: effectiveHandleSize.height, alignment: .center)
            .offset(x: clampedOffset(currentOffset, in: width), y: 0)
            .gesture(longPressDrag)
            .environment(\.partitionDragState, publicDragState)
    }

    public var body: some View {
        GeometryReader { (proxy: GeometryProxy) in
            HStack {
                let width = proxy.frame(in: .local).width
                let offset = clampedOffset(currentOffset, in: width)

                left
                    .frame(width: paddingFactor * pctSplit * width + offset)
                    .environment(\.partitionDragState, publicDragState)

                Divider()

                right
                    .frame(width: paddingFactor * (1 - pctSplit) * width - offset)
                    .environment(\.partitionDragState, publicDragState)
            }
            .overlay(generateHandle(in: proxy.frame(in: .local).width), alignment: .center)
        }
    }
}



// MARK: Init

extension HPart: View where Left: View, Right: View, Handle: View {
    
    /// # Horizontal Partition With Custom Handle
    ///
    /// - parameters:
    ///    - left: Any type of View within a closure.
    ///    - right: Any type of View within a closure
    ///    - handle: Any type of View within a closure. The `Handle` is the view that the user will use to drag and resize the partitions.
    @inlinable public init(@ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right, @ViewBuilder handle: () -> Handle) {
        self.left = left()
        self.right = right()
        self.handle = handle()
    }
    
    /// # Horizontal Partition With Custom Handle
    ///
    /// - parameters:
    ///    - pctSplit: The ratio of space the left takes up compared to the right. Use values between 0 and 1
    ///    - left: Any type of View within a closure.
    ///    - right: Any type of View within a closure
    ///    - handle: Any type of View within a closure. The `Handle` is the view that the user will use to drag and resize the partitions.
    @inlinable public init(pctSplit: CGFloat, @ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right, @ViewBuilder handle: () -> Handle) {
        self.pctSplit = pctSplit
        self.left = left()
        self.right = right()
        self.handle = handle()
    }
}

extension HPart where Left: View, Right: View, Handle == Capsule {
    
    /// # Horizontal Partition With Default Handle
    ///
    /// - parameters:
    ///    - left: Any type of View within a closure.
    ///    - right: Any type of View within a closure
    ///
    /// - note
    ///  The `Handle` used here is a capsule that is taller than it is wide.
    @inlinable public init(@ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self.left = left()
        self.right = right()
        self.handle = Capsule()
    }
    
    /// # Horizontal Partition With Default Handle
    ///
    /// - parameters:
    ///    - pctSplit: The ratio of space the left takes up compared to the right. Use values between 0 and 1
    ///    - left: Any type of View within a closure.
    ///    - right: Any type of View within a closure
    ///
    /// - note
    ///  The `Handle` used here is a capsule that is taller than it is wide.
    @inlinable public init(pctSplit: CGFloat, @ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self.pctSplit = pctSplit
        self.left = left()
        self.right = right()
        self.handle = Capsule()
    }
    
}
