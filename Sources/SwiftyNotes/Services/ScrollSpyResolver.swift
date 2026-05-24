import Foundation

/// Pure resolver behind the Outline panel's "active heading" highlight
/// and the breadcrumb strip above the editor.
///
/// Inputs:
///  - `positions`: each heading's y coordinate relative to the top of
///    the scroll container, in document order.
///  - `scrollTop`: the container's current scroll offset.
///  - `anchorOffset`: how far below the visible top the activation line
///    sits. Default 80 px matches the design's "your-here" line.
///
/// Algorithm: pick the heading with the largest y that's still at or
/// above the anchor line. If multiple headings share that y (e.g. a
/// short H2 immediately followed by an H3), the later one wins — that
/// matches what the user visually reads as "the most recent heading
/// they passed."
enum ScrollSpyResolver {
    static func activeHeadingID(
        positions: [(id: String, y: Double)],
        scrollTop: Double,
        anchorOffset: Double = 80,
    ) -> String? {
        let anchor = scrollTop + anchorOffset
        var bestID: String?
        var bestY = -Double.infinity
        for (id, y) in positions where y <= anchor {
            if y >= bestY {
                bestID = id
                bestY = y
            }
        }
        return bestID
    }
}
