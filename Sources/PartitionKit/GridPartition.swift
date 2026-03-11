//
//  GridPartition.swift
//
//
//  Created by Kieran Brown on 10/26/19.
//

import SwiftUI

/// # Grid Partition
/// Creates a flexible container view with four separate partitions and a draggable `Handle` in the center.
/// Don't be afraid of the syntax, The View takes at minimum four closures each containing some type that conforms to `View`.
/// The reason that 5 separate generic arguments are used is so that the user can avoid wrapping everything in an `AnyView`.
///
/// - note
/// the syntax looks something like this, So if closures are still kind of new to you just think that you are sending a letter(`View`) to somebody  and it needs an Envelope(`{}`) to get there.
/// ```
/// GridPart(topLeft: {
///     Circle()
/// }, topRight: {
///    Rectangle()
/// }, bottomLeft: {
///     RoundedRectangle(cornerRadius: 25)
/// }, bottomRight {
///     Capsule()
/// }), {
///     CrossHair()
/// }
///
///```
///
/// Optionally the user may specify a specific view to be used as the `Handle` otherwise the View `CrossHair` will be used as default
@MainActor public struct GridPart<TopLeft, TopRight, BottomLeft, BottomRight, Handle> where TopLeft: View , TopRight: View, BottomLeft: View, BottomRight:View, Handle: View {
    
    public var topLeft: TopLeft
    public var topRight: TopRight
    public var bottomLeft: BottomLeft
    public var bottomRight: BottomRight
    public var handle: Handle
    
    /// Amount of time it takes before a gesture is recognized as a longPress, the precursor to the drag.
    var minimumLongPressDuration = 0.05
    /// Size of the `Handle`
    var handleSize: CGSize = CGSize(width: 40, height: 40)
    public var pctSplit: CGSize = CGSize(width: 0.5, height: 0.5)
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

    // Clamp the 2-D offset so that no quadrant ever gets a negative frame dimension.
    //
    // Horizontal axis (width):
    //   left  width  = paddingFactor * pctSplit.width  * width  + offset.width  >= 0
    //   right width  = paddingFactor * (1-pctSplit.width)  * width  - offset.width  >= 0
    //
    // Vertical axis (height):
    //   top    height = paddingFactor * pctSplit.height * height + offset.height >= 0
    //   bottom height = paddingFactor * (1-pctSplit.height) * height - offset.height >= 0
    func clampedOffset(_ offset: CGSize, in size: CGSize) -> CGSize {
        let minX = -paddingFactor * pctSplit.width  * size.width
        let maxX =  paddingFactor * (1 - pctSplit.width)  * size.width
        let minY = -paddingFactor * pctSplit.height * size.height
        let maxY =  paddingFactor * (1 - pctSplit.height) * size.height
        return CGSize(
            width:  min(max(offset.width,  minX), maxX),
            height: min(max(offset.height, minY), maxY)
        )
    }

    // A bit of a convienence so I dont have to write this again and again.
    var currentOffset: CGSize {
        CGSize(width: viewState.width + dragState.translation.width,
               height: viewState.height + dragState.translation.height)
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
    func generateHandle(in size: CGSize) -> some View {
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
                let proposed = CGSize(
                    width:  viewState.width  + drag.translation.width,
                    height: viewState.height + drag.translation.height
                )
                let clamped = clampedOffset(proposed, in: size)
                viewState.width  = clamped.width
                viewState.height = clamped.height
            }

        let configuration = PartitionHandleStyleConfiguration(
            handle: AnyView(handle),
            dragState: publicDragState
        )

        return handleStyle.makeBody(configuration: configuration)
            .frame(width: effectiveHandleSize.width, height: effectiveHandleSize.height, alignment: .center)
            .offset(clampedOffset(currentOffset, in: size))
            .gesture(longPressDrag)
            .environment(\.partitionDragState, publicDragState)
    }
    
    public var body: some View {
        GeometryReader { (proxy: GeometryProxy) in
            let size = proxy.frame(in: .local).size
            let offset = clampedOffset(currentOffset, in: size)

            VStack {
                // Top
                HStack {
                    topLeft
                        .frame(width: paddingFactor * pctSplit.width * size.width + offset.width)
                        .environment(\.partitionDragState, publicDragState)

                    Divider()

                    topRight
                        .frame(width: paddingFactor * (1 - pctSplit.width) * size.width - offset.width)
                        .environment(\.partitionDragState, publicDragState)
                }
                .frame(height: paddingFactor * pctSplit.height * size.height + offset.height)

                Divider()

                // Bottom
                HStack {
                    bottomLeft
                        .frame(width: paddingFactor * pctSplit.width * size.width + offset.width)
                        .environment(\.partitionDragState, publicDragState)

                    Divider()

                    bottomRight
                        .frame(width: paddingFactor * (1 - pctSplit.width) * size.width - offset.width)
                        .environment(\.partitionDragState, publicDragState)
                }
                .frame(height: paddingFactor * (1 - pctSplit.height) * size.height - offset.height)
            }
            .overlay(generateHandle(in: size), alignment: .center)
        }
    }
}

extension GridPart: View where TopLeft:View, TopRight: View, BottomLeft: View, BottomRight: View, Handle: View {
    
    /// # GridPartition With Custom Handle
    /// - parameters:
    ///   - topLeft Any type of View within a closure.
    ///   - topRight Any type of View within a closure.
    ///   - bottomLeft Any type of View within a closure.
    ///   - bottomLeft Any type of View within a closure.
    ///   - handle Any type of View within a closure, This is the view that the user will drag to resize all the others.
    @inlinable public init(@ViewBuilder topLeft: () -> TopLeft, @ViewBuilder topRight: () -> TopRight,@ViewBuilder  bottomLeft: () -> BottomLeft, @ViewBuilder bottomRight: () -> BottomRight, @ViewBuilder handle: () -> Handle ) {
        self.topLeft = topLeft()
        self.topRight = topRight()
        self.bottomLeft = bottomLeft()
        self.bottomRight = bottomRight()
        self.handle = handle()
    }
    
    /// # GridPartition With Custom Handle
    /// - parameters:
    ///   - pctSplit The inital percentage size each partition should take up
    ///   - topLeft Any type of View within a closure.
    ///   - topRight Any type of View within a closure.
    ///   - bottomLeft Any type of View within a closure.
    ///   - bottomLeft Any type of View within a closure.
    ///   - handle Any type of View within a closure, This is the view that the user will drag to resize all the others.
    @inlinable public init(pctSplit: CGSize, @ViewBuilder topLeft: () -> TopLeft, @ViewBuilder topRight: () -> TopRight, @ViewBuilder  bottomLeft: () -> BottomLeft, @ViewBuilder bottomRight: () -> BottomRight, @ViewBuilder handle: () -> Handle ) {
        self.pctSplit = pctSplit
        self.topLeft = topLeft()
        self.topRight = topRight()
        self.bottomLeft = bottomLeft()
        self.bottomRight = bottomRight()
        self.handle = handle()
    }
}

extension GridPart where Handle == CrossHair, TopLeft:View, TopRight: View, BottomLeft: View, BottomRight: View {
    
    /// # GridPartition With Crosshair Handle
    /// A slight convienence because you do not have to specify a handle, the default  `CrossHair` is used instead.
    ///
    /// - parameters:
    ///   - topLeft Any type of View within a closure.
    ///   - topRight Any type of View within a closure.
    ///   - bottomLeft Any type of View within a closure.
    ///   - bottomLeft Any type of View within a closure.
    ///
    /// Uses the default `CrossHair` as the `Handle`.
    @inlinable public init(@ViewBuilder topLeft: () -> TopLeft, @ViewBuilder topRight: () -> TopRight,@ViewBuilder  bottomLeft: () -> BottomLeft, @ViewBuilder bottomRight: () -> BottomRight) {
        self.topLeft = topLeft()
        self.topRight = topRight()
        self.bottomLeft = bottomLeft()
        self.bottomRight = bottomRight()
        self.handle = CrossHair()
    }
    
    /// # GridPartition With Crosshair Handle
    /// A slight convienence because you do not have to specify a handle, the default  `CrossHair` is used instead.
    ///
    /// - parameters:
    ///   - pctSplit The inital percentage size each partition should take up
    ///   - topLeft Any type of View within a closure.
    ///   - topRight Any type of View within a closure.
    ///   - bottomLeft Any type of View within a closure.
    ///   - bottomLeft Any type of View within a closure.
    ///
    /// Uses the default `CrossHair` as the `Handle`.
    @inlinable public init(pctSplit: CGSize, @ViewBuilder topLeft: () -> TopLeft, @ViewBuilder topRight: () -> TopRight,@ViewBuilder  bottomLeft: () -> BottomLeft, @ViewBuilder bottomRight: () -> BottomRight) {
        self.pctSplit = pctSplit
        self.topLeft = topLeft()
        self.topRight = topRight()
        self.bottomLeft = bottomLeft()
        self.bottomRight = bottomRight()
        self.handle = CrossHair()
    }
}
