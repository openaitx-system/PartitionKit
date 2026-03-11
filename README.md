# Partition Kit

![partition kit logo](https://github.com/kieranb662/PartitionKit/blob/master/partition-kit-logo.png)

Recently Featured In [Top 10 Trending Android and iOS Libraries in October](https://medium.com/better-programming/top-10-trending-android-and-ios-libraries-in-october-e7dd18f8b75b) and in [5 iOS libraries to enhance your app](https://medium.com/better-programming/5-ios-libraries-to-enhance-your-app-17ae7ed350db)!

![grid](/nestedGrid.gif)

What is PartitionKit?
- It is the solution to the need for composable and dynamically sized user interface content in SwiftUI.
- also the first piece of software I have ever made into a library so please be gentle (both with use cases and with my heart).

What PartitionKit is **not**?
- PartitionKit is not a means to work with any form of stored data. This is not for partitioning hard drives or any other type of formattable data drive.


## Requirements

PartitionKit requires the SwiftUI framework, so only these platforms are supported:

* macOS 10.15 or Greater
* iOS 13 or Greater
* watchOS 6 or Greater


## How To Add To Your Project

1. Snag that URL from the github repo
2. In Xcode -> File -> Swift Packages -> Add Package Dependencies
3. Paste the URL into the box
4. Specify the minimum version number (This is new so 1.0.0 and greater will work).

## Less Than 2 Minute Tutorial Video

[![Tutorial Video: How To Use PartitionKit](https://img.youtube.com/vi/RSnEevQcqjk/0.jpg)](https://www.youtube.com/watch?v=RSnEevQcqjk)


## How To Use


### Vertical Partition

1. Decide on what view you would like to have on `Top`, which you would like to have on the `Bottom`, and optionally a `Handle` to be used to drag the partitions to different sizes.
2. Do This
``` Swift
VPart(top: {
    MyTopView()
    }, bottom: {
    MyBottomView()
    }) {
    MyHandle()
}
```

### Horizontal Partition

1. Decide on what view you would like to have on `Left`, which you would like to have on the `Right`, and optionally a `Handle` to be used to drag the partitions to different sizes.
2. Do This
``` Swift
HPart(left: {
    MyLeftView()
    }, right: {
    MyRightView()
    }) {
    MyHandle()
}
```

### GridPartition

1. Decide on what Views will go in each corner: `TopLeft`, `TopRight`, `BottomLeft`, `BottomRight`, and optionally a `Handle` for the user to drag and resize the views with.
2. Do this
``` Swift
    GridPart(topLeft: {
        MyTopLeftView()
        }, topRight: {
        MyTopRightView()
        }, bottomLeft: {
        MyBottomLeftView()
        }, bottomRight: {
        MyBottomRightView()
        }) {
        MyHandle()
}
```

### ListGridPartition

Display any `RandomAccessCollection` of `Identifiable` items as a scrollable list of resizable rows. Each divider between rows is a draggable handle.

``` Swift
struct ColorItem: Identifiable {
    let id: Int
    let color: Color
}

let items = [
    ColorItem(id: 0, color: .red),
    ColorItem(id: 1, color: .blue),
    ColorItem(id: 2, color: .green),
]

// Default Capsule handle, equal initial row heights
ListGridPart(items) { item in
    RoundedRectangle(cornerRadius: 12)
        .fill(item.color)
        .padding(4)
}

// Custom initial fractions (top row takes 50 %, the rest share the remainder)
ListGridPart(items, fractions: [0.5, 0.25, 0.25]) { item in
    RoundedRectangle(cornerRadius: 12)
        .fill(item.color)
        .padding(4)
}

// Custom handle
ListGridPart(items, handle: { Capsule().fill(Color.accentColor) }) { item in
    RoundedRectangle(cornerRadius: 12)
        .fill(item.color)
        .padding(4)
}
```

All the partition styling modifiers (`.partitionHandleStyle`, `.partitionHandleSize`, `.partitionLongPressDuration`) propagate into `ListGridPart` just like the other partition types.

### Customising the initial layout

Every partition type (`VPart`, `HPart`, `GridPart`, `ListGridPart`) accepts an optional `pctSplit` (or `fractions` for list partitions) parameter that controls the initial layout proportions:

``` Swift
// VPart: top takes 70 % of the height
VPart(pctSplit: 0.7, top: { TopView() }, bottom: { BottomView() })

// HPart: left takes 30 % of the width
HPart(pctSplit: 0.3, left: { LeftView() }, right: { RightView() })

// GridPart: 60 % width on the left, 40 % height on the top
GridPart(pctSplit: CGSize(width: 0.6, height: 0.4),
         topLeft: { A() }, topRight: { B() },
         bottomLeft: { C() }, bottomRight: { D() })
```

### Customising handle size and drag sensitivity

Use `.partitionHandleSize(_:)` and `.partitionLongPressDuration(_:)` to tune the handle appearance and responsiveness for an entire view hierarchy:

``` Swift
VPart(top: { TopView() }, bottom: { BottomView() })
    .partitionHandleSize(CGSize(width: 120, height: 20))   // wider handle
    .partitionLongPressDuration(0.0)                        // drag starts immediately
```

Both modifiers propagate down through nested partitions, so a single call on a parent container applies to all children.

## Styling Handles During Drag

PartitionKit exposes two complementary APIs for adjusting the appearance of handles and content views while a drag is in progress. Both APIs mirror the style of built-in SwiftUI components.

### Reading drag state with the environment

Every view inside a partition receives the current `PartitionDragState` through the SwiftUI environment. Read it with `@Environment(\.partitionDragState)` inside any handle or content view.

`PartitionDragState` has three cases:

| Case | Meaning |
|------|---------|
| `.inactive` | No gesture is active |
| `.pressing` | A long press has been recognized |
| `.dragging` | The handle is actively being dragged |

It also provides two convenience properties: `isActive` (true when pressing or dragging) and `isDragging` (true only when dragging).

``` Swift
struct MyHandle: View {
    @Environment(\.partitionDragState) var dragState

    var body: some View {
        Capsule()
            .fill(dragState.isDragging ? Color.accentColor : Color.secondary)
            .scaleEffect(dragState.isActive ? 1.2 : 1.0)
            .animation(.spring(), value: dragState)
    }
}

VPart(top: { TopView() }, bottom: { BottomView() }) {
    MyHandle()
}
```

Content views inside the partition also receive the environment value, so you can dim or highlight them while the handle is moving:

``` Swift
struct FadingContent: View {
    @Environment(\.partitionDragState) var dragState

    var body: some View {
        MyContentView()
            .opacity(dragState.isDragging ? 0.5 : 1.0)
            .animation(.easeInOut, value: dragState)
    }
}

HPart(left: { FadingContent() }, right: { FadingContent() })
```

### Applying a reusable handle style with `.partitionHandleStyle(_:)`

For reusable, composable styling that applies to every handle inside a view hierarchy, conform to `PartitionHandleStyle` and apply it with the `.partitionHandleStyle(_:)` modifier. This mirrors how `.buttonStyle(_:)` works in SwiftUI.

`makeBody(configuration:)` receives a `PartitionHandleStyleConfiguration` that provides:

- `configuration.handle` - the original handle view as an `AnyView`
- `configuration.dragState` - the current `PartitionDragState`

``` Swift
struct HighlightHandleStyle: PartitionHandleStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.handle
            .foregroundColor(configuration.dragState.isDragging ? .yellow : .white)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.yellow.opacity(configuration.dragState.isActive ? 1 : 0), lineWidth: 2)
            )
            .scaleEffect(configuration.dragState.isActive ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.dragState)
    }
}

VPart(top: { TopView() }, bottom: { BottomView() })
    .partitionHandleStyle(HighlightHandleStyle())
```

The modifier propagates down the hierarchy, so a single call on a parent applies to all nested partitions:

``` Swift
GridPart(topLeft: { A() }, topRight: { B() }, bottomLeft: { C() }, bottomRight: { D() })
    .partitionHandleStyle(HighlightHandleStyle())
```

### Built-in styles

Two styles ship with the library:

| Style | Description |
|-------|-------------|
| `DefaultPartitionHandleStyle` | Shows a white circle stroke outline when dragging. Applied automatically when no style is set. |
| `ScaledPartitionHandleStyle` | Scales the handle up while active. Accepts an optional `activeScale` parameter (default `1.2`). |

``` Swift
HPart(left: { LeftView() }, right: { RightView() })
    .partitionHandleStyle(ScaledPartitionHandleStyle(activeScale: 1.4))
```


## Examples

Copy and paste this. I have added named pictures for how the views should look. Using dark mode so light mode colors may look different.

| HPart                   | VPart                   | GridPart                      | NestGrids                              | Mixed                       |
|-------------------------|-------------------------|-------------------------------|----------------------------------------|-----------------------------|
| ![HPart](/hExample.png) | ![VPart](/vExample.png) | ![GridPart](/gridExample.png) | ![Nested Grid](/nestedGridExample.png) | ![Mixed](/nestedExample.png) |

``` Swift
import SwiftUI
import PartitionKit



struct ContentView: View {
    var vExample: some View {
        VPart(top: {
            RoundedRectangle(cornerRadius: 25).foregroundColor(.purple)
        }) {
            Circle().foregroundColor(.yellow)
        }
    }
    
    var hExample: some View {
        HPart(left: {
            RoundedRectangle(cornerRadius: 10).foregroundColor(.blue)
        }) {
            Circle().foregroundColor(.orange)
        }
    }
    
    var nestedExample: some View {
        VPart(top: {
            hExample
        }) {
            vExample
        }
    }
    
    var gridExample: some View {
        GridPart(topLeft: {
            RoundedRectangle(cornerRadius: 25).foregroundColor(.purple)
        }, topRight: {
            Circle().foregroundColor(.yellow)
        }, bottomLeft: {
            Circle().foregroundColor(.green)
        }) {
            RoundedRectangle(cornerRadius: 25).foregroundColor(.blue)
        }
    }
    
    var nestedGridsExample: some View {
        GridPart(topLeft: {
            gridExample
        }, topRight: {
            gridExample
        }, bottomLeft: {
            gridExample
        }) {
            gridExample
        }
    }
    
    var body: some View {
        nestedExample
        
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
```
