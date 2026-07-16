import PhosphorSwift
import SwiftUI

enum PlancalIcon: Hashable {
    case today
    case plan
    case notes
    case settings
    case day
    case week
    case month
    case quarter
    case year
    case add
    case close
    case disclosure
    case previous
    case next
    case confirm
    case edit
    case delete
    case pin
    case calendar
    case calendarAccess
    case clock
    case location
    case recurrence
    case synced
    case cloud
    case cloudWarning
    case morning
    case complete
    case incomplete
    case carriedForward
    case priority
    case essential
    case priorityGentle
    case priorityImportant
    case priorityEssential
    case text
    case heading1
    case heading2
    case heading3
    case bulletedList
    case numberedList
    case checklist
    case quote
    case code
    case link
    case bold
    case italic
    case strikethrough
    case newNote

    fileprivate var phosphor: Ph {
        switch self {
        case .today, .day: .sun
        case .plan, .week: .calendarDots
        case .notes: .notepad
        case .settings: .slidersHorizontal
        case .month: .calendarBlank
        case .quarter: .chartBar
        case .year: .calendarStar
        case .add: .plus
        case .close: .x
        case .disclosure: .caretRight
        case .previous: .caretLeft
        case .next: .caretRight
        case .confirm: .check
        case .edit: .pencilSimple
        case .delete: .trash
        case .pin: .pushPin
        case .calendar: .calendarBlank
        case .calendarAccess: .calendarCheck
        case .clock: .clock
        case .location: .mapPin
        case .recurrence: .arrowsClockwise
        case .synced: .cloudCheck
        case .cloud: .cloud
        case .cloudWarning: .cloudWarning
        case .morning: .sunHorizon
        case .complete: .checkCircle
        case .incomplete: .circle
        case .carriedForward: .arrowBendRightDown
        case .priority: .flag
        case .essential: .warningCircle
        case .priorityGentle: .feather
        case .priorityImportant: .arrowUp
        case .priorityEssential: .warningOctagon
        case .text: .paragraph
        case .heading1: .textHOne
        case .heading2: .textHTwo
        case .heading3: .textHThree
        case .bulletedList: .listBullets
        case .numberedList: .listNumbers
        case .checklist: .listChecks
        case .quote: .quotes
        case .code: .code
        case .link: .link
        case .bold: .textB
        case .italic: .textItalic
        case .strikethrough: .textStrikethrough
        case .newNote: .notePencil
        }
    }
}

enum PlancalIconWeight: Hashable {
    case light
    case regular
    case bold
    case fill
    case duotone

    fileprivate var phosphor: Ph.IconWeight {
        switch self {
        case .light: .light
        case .regular: .regular
        case .bold: .bold
        case .fill: .fill
        case .duotone: .duotone
        }
    }
}

struct PlancalGlyph: View {
    let icon: PlancalIcon
    var weight: PlancalIconWeight = .regular
    var size: CGFloat = 20

    var body: some View {
        icon.phosphor
            .weight(weight.phosphor)
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

struct PlancalIconLabel: View {
    let title: String
    let icon: PlancalIcon
    var weight: PlancalIconWeight = .regular
    var size: CGFloat = 18

    var body: some View {
        Label {
            Text(title)
        } icon: {
            PlancalGlyph(icon: icon, weight: weight, size: size)
        }
    }
}

/// Native menus, pickers, and tab bars detach an image from its SwiftUI frame.
/// PhosphorSwift exposes resizable images, so those containers would otherwise
/// lay them out at the source asset's full size. This rasterized variant keeps a
/// fixed intrinsic size when SwiftUI promotes the image into platform chrome.
struct PlancalNativeGlyph: View {
    let icon: PlancalIcon
    var weight: PlancalIconWeight = .regular
    var size: CGFloat = 18

    var body: some View {
        PlancalNativeIconRenderer.image(icon: icon, weight: weight, size: size)
            .renderingMode(.template)
    }
}

struct PlancalNativeIconLabel: View {
    let title: String
    let icon: PlancalIcon
    var weight: PlancalIconWeight = .regular
    var size: CGFloat = 18

    var body: some View {
        Label {
            Text(title)
        } icon: {
            PlancalNativeGlyph(icon: icon, weight: weight, size: size)
        }
    }
}

@MainActor
private enum PlancalNativeIconRenderer {
    private struct Key: Hashable {
        let icon: PlancalIcon
        let weight: PlancalIconWeight
        let pixelSize: Int
    }

    private static var cache: [Key: Image] = [:]

    static func image(icon: PlancalIcon, weight: PlancalIconWeight, size: CGFloat) -> Image {
        let key = Key(icon: icon, weight: weight, pixelSize: Int((size * 10).rounded()))
        if let cached = cache[key] { return cached }

        let renderer = ImageRenderer(
            content: icon.phosphor
                .weight(weight.phosphor)
                .renderingMode(.template)
                .foregroundStyle(Color.black)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        )

        #if os(macOS)
        renderer.scale = 2
        guard let platformImage = renderer.nsImage else {
            return icon.phosphor.weight(weight.phosphor)
        }
        let result = Image(nsImage: platformImage)
        #else
        renderer.scale = 3
        guard let platformImage = renderer.uiImage else {
            return icon.phosphor.weight(weight.phosphor)
        }
        let result = Image(uiImage: platformImage)
        #endif

        cache[key] = result
        return result
    }
}

private struct PlancalHoverFeedback: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    let scale: CGFloat
    let lifts: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1)
            .brightness(isHovered ? 0.025 : 0)
            .shadow(
                color: lifts && isHovered ? Color.black.opacity(0.09) : .clear,
                radius: 8,
                y: lifts && isHovered ? 3 : 0
            )
            .onHover { isHovered = $0 }
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: isHovered)
    }
}

extension View {
    func plancalHoverEffect(scale: CGFloat = 1.025, lifts: Bool = false) -> some View {
        modifier(PlancalHoverFeedback(scale: scale, lifts: lifts))
    }
}
