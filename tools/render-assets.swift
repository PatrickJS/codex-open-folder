import AppKit
import Foundation

let baseWidth: CGFloat = 1280
let baseHeight: CGFloat = 720

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    let red = CGFloat((hex >> 16) & 0xff) / 255
    let green = CGFloat((hex >> 8) & 0xff) / 255
    let blue = CGFloat(hex & 0xff) / 255
    return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

func clamp(_ value: CGFloat, _ lower: CGFloat = 0, _ upper: CGFloat = 1) -> CGFloat {
    min(max(value, lower), upper)
}

func ease(_ value: CGFloat) -> CGFloat {
    let t = clamp(value)
    return t * t * (3 - 2 * t)
}

func progress(_ frame: Int, _ start: Int, _ end: Int) -> CGFloat {
    if frame <= start { return 0 }
    if frame >= end { return 1 }
    return ease(CGFloat(frame - start) / CGFloat(end - start))
}

struct Canvas {
    let image: NSImage
    let width: CGFloat
    let height: CGFloat
    let sx: CGFloat
    let sy: CGFloat
    let ss: CGFloat

    init(width: CGFloat, height: CGFloat) {
        self.image = NSImage(size: NSSize(width: width, height: height))
        self.width = width
        self.height = height
        self.sx = width / baseWidth
        self.sy = height / baseHeight
        self.ss = min(sx, sy)
    }

    func x(_ value: CGFloat) -> CGFloat { value * sx }
    func y(_ value: CGFloat) -> CGFloat { value * sy }
    func w(_ value: CGFloat) -> CGFloat { value * sx }
    func h(_ value: CGFloat) -> CGFloat { value * sy }
    func font(_ value: CGFloat) -> CGFloat { value * ss }

    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: self.x(x), y: self.height - self.y(y) - self.h(height), width: self.w(width), height: self.h(height))
    }

    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: self.x(x), y: self.height - self.y(y))
    }
}

func fillRound(_ canvas: Canvas, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat, _ fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
    let path = NSBezierPath(roundedRect: canvas.rect(x, y, w, h), xRadius: canvas.font(radius), yRadius: canvas.font(radius))
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = canvas.font(lineWidth)
        path.stroke()
    }
}

func fillRect(_ canvas: Canvas, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ fill: NSColor) {
    fill.setFill()
    canvas.rect(x, y, w, h).fill()
}

func drawText(_ canvas: Canvas, _ text: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, color textColor: NSColor = .white, align: NSTextAlignment = .left) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    paragraph.lineBreakMode = .byTruncatingTail
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: canvas.font(size), weight: weight),
        .foregroundColor: textColor,
        .paragraphStyle: paragraph
    ]
    (text as NSString).draw(in: canvas.rect(x, y, w, h), withAttributes: attrs)
}

func drawFolderIcon(_ canvas: Canvas, _ x: CGFloat, _ y: CGFloat, selected: Bool = false) {
    let tab = NSBezierPath(roundedRect: canvas.rect(x + 4, y, 42, 15), xRadius: canvas.font(4), yRadius: canvas.font(4))
    color(selected ? 0x63b3ff : 0x4ba9e9).setFill()
    tab.fill()
    let body = NSBezierPath(roundedRect: canvas.rect(x, y + 8, 58, 42), xRadius: canvas.font(7), yRadius: canvas.font(7))
    color(selected ? 0x75c8ff : 0x55b7ee).setFill()
    body.fill()
    color(0xffffff, selected ? 0.32 : 0.18).setStroke()
    body.lineWidth = canvas.font(1)
    body.stroke()
}

func drawCursor(_ canvas: Canvas, x: CGFloat, y: CGFloat, click: CGFloat) {
    let path = NSBezierPath()
    path.move(to: canvas.point(x, y))
    path.line(to: canvas.point(x + 0, y + 42))
    path.line(to: canvas.point(x + 29, y + 28))
    path.line(to: canvas.point(x + 15, y + 24))
    path.line(to: canvas.point(x + 26, y + 50))
    path.line(to: canvas.point(x + 16, y + 54))
    path.line(to: canvas.point(x + 5, y + 29))
    path.close()
    color(0xffffff).setFill()
    path.fill()
    color(0x0c0f14, 0.65).setStroke()
    path.lineWidth = canvas.font(2)
    path.stroke()

    if click > 0 {
        color(0x1282ff, 0.22 * click).setStroke()
        let ring = NSBezierPath(ovalIn: canvas.rect(x - 18 * click, y - 18 * click, 52 * click, 52 * click))
        ring.lineWidth = canvas.font(4)
        ring.stroke()
    }
}

func drawMenuRow(_ canvas: Canvas, _ text: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, highlighted: Bool = false, chevron: Bool = false, icon: String? = nil) {
    if highlighted {
        fillRound(canvas, x + 12, y - 4, w - 24, 46, 9, color(0x0a84ff, 0.95))
    }
    if let icon {
        drawText(canvas, icon, x + 30, y + 4, 28, 30, size: 21, weight: .semibold, color: color(0xe8edf4), align: .center)
    }
    drawText(canvas, text, x + 76, y + 2, w - 122, 36, size: 24, weight: .medium, color: color(0xf4f6fb))
    if chevron {
        drawText(canvas, ">", x + w - 52, y + 1, 28, 36, size: 29, weight: .semibold, color: color(0xd7dbe3), align: .center)
    }
}

func drawCodexMark(_ canvas: Canvas, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, alpha: CGFloat = 1) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.cgContext.setAlpha(alpha)

    fillRound(canvas, x, y, size, size, size * 0.22, color(0xf8fbff), stroke: color(0xdfe6f2, 0.85), lineWidth: 1.2)

    let cloud = NSBezierPath()
    cloud.move(to: canvas.point(x + size * 0.20, y + size * 0.56))
    cloud.curve(to: canvas.point(x + size * 0.34, y + size * 0.39),
                controlPoint1: canvas.point(x + size * 0.19, y + size * 0.45),
                controlPoint2: canvas.point(x + size * 0.26, y + size * 0.40))
    cloud.curve(to: canvas.point(x + size * 0.52, y + size * 0.25),
                controlPoint1: canvas.point(x + size * 0.39, y + size * 0.27),
                controlPoint2: canvas.point(x + size * 0.48, y + size * 0.22))
    cloud.curve(to: canvas.point(x + size * 0.67, y + size * 0.32),
                controlPoint1: canvas.point(x + size * 0.59, y + size * 0.25),
                controlPoint2: canvas.point(x + size * 0.63, y + size * 0.27))
    cloud.curve(to: canvas.point(x + size * 0.83, y + size * 0.50),
                controlPoint1: canvas.point(x + size * 0.77, y + size * 0.31),
                controlPoint2: canvas.point(x + size * 0.84, y + size * 0.39))
    cloud.curve(to: canvas.point(x + size * 0.75, y + size * 0.74),
                controlPoint1: canvas.point(x + size * 0.91, y + size * 0.59),
                controlPoint2: canvas.point(x + size * 0.87, y + size * 0.72))
    cloud.curve(to: canvas.point(x + size * 0.47, y + size * 0.76),
                controlPoint1: canvas.point(x + size * 0.68, y + size * 0.82),
                controlPoint2: canvas.point(x + size * 0.55, y + size * 0.83))
    cloud.curve(to: canvas.point(x + size * 0.22, y + size * 0.68),
                controlPoint1: canvas.point(x + size * 0.36, y + size * 0.79),
                controlPoint2: canvas.point(x + size * 0.25, y + size * 0.77))
    cloud.curve(to: canvas.point(x + size * 0.20, y + size * 0.56),
                controlPoint1: canvas.point(x + size * 0.13, y + size * 0.65),
                controlPoint2: canvas.point(x + size * 0.13, y + size * 0.57))
    cloud.close()

    NSGraphicsContext.saveGraphicsState()
    cloud.addClip()
    let cloudGradient = NSGradient(colors: [color(0xa98cff), color(0x5f9cff), color(0x352dff)])!
    cloudGradient.draw(in: canvas.rect(x + size * 0.14, y + size * 0.20, size * 0.76, size * 0.66), angle: -55)
    NSGraphicsContext.restoreGraphicsState()

    color(0x89a7ff, 0.72).setStroke()
    cloud.lineWidth = canvas.font(size * 0.018)
    cloud.stroke()

    let chevron = NSBezierPath()
    chevron.move(to: canvas.point(x + size * 0.38, y + size * 0.44))
    chevron.line(to: canvas.point(x + size * 0.48, y + size * 0.54))
    chevron.line(to: canvas.point(x + size * 0.38, y + size * 0.64))
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    chevron.lineWidth = canvas.font(size * 0.08)
    color(0xf8fbff, 0.96).setStroke()
    chevron.stroke()

    let prompt = NSBezierPath()
    prompt.move(to: canvas.point(x + size * 0.58, y + size * 0.63))
    prompt.line(to: canvas.point(x + size * 0.76, y + size * 0.63))
    prompt.lineCapStyle = .round
    prompt.lineWidth = canvas.font(size * 0.075)
    prompt.stroke()

    NSGraphicsContext.restoreGraphicsState()
}

func drawCodexAppIcon(_ canvas: Canvas, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, alpha: CGFloat = 1) {
    let iconPath = "/Applications/Codex.app/Contents/Resources/icon.icns"
    guard let icon = NSImage(contentsOfFile: iconPath) else {
        drawCodexMark(canvas, x, y, size, alpha: alpha)
        return
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.cgContext.setAlpha(alpha)
    icon.draw(in: canvas.rect(x, y, size, size), from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

func drawFinder(_ canvas: Canvas) {
    fillRound(canvas, 86, 94, 548, 432, 20, color(0x11151c, 0.96), stroke: color(0x3b404b))
    fillRect(canvas, 86, 94, 548, 58, color(0x171c24, 0.96))
    drawText(canvas, "Finder", 122, 112, 180, 34, size: 23, weight: .semibold, color: color(0xe9edf4))
    fillRound(canvas, 520, 111, 74, 28, 14, color(0x262d39))
    drawText(canvas, "List", 540, 115, 42, 24, size: 14, weight: .medium, color: color(0xbfc7d5), align: .center)

    let rows: [(String, Bool)] = [
        ("codex-open-folder", true),
        ("source", false),
        ("scripts", false),
        ("README.md", false),
        ("install.zsh", false)
    ]
    for (index, item) in rows.enumerated() {
        let y = CGFloat(170 + index * 58)
        if item.1 {
            fillRound(canvas, 114, y - 7, 486, 52, 11, color(0x0a84ff, 0.92), stroke: color(0x92c9ff, 0.72), lineWidth: 1.4)
        }
        drawFolderIcon(canvas, 132, y, selected: item.1)
        drawText(canvas, item.0, 204, y + 4, 330, 36, size: 24, weight: item.1 ? .semibold : .medium, color: color(0xf5f7fb))
    }
}

func drawSimpleContextMenu(_ canvas: Canvas, alpha: CGFloat, highlight: CGFloat) {
    guard alpha > 0 else { return }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.cgContext.setAlpha(alpha)
    fillRound(canvas, 356, 166, 432, 326, 24, color(0x101316, 0.98), stroke: color(0x596170, 0.82), lineWidth: 1.2)
    drawMenuRow(canvas, "Open", 356, 196, 432, icon: "O")
    drawMenuRow(canvas, "Rename", 356, 248, 432, icon: "R")
    drawMenuRow(canvas, "Get Info", 356, 300, 432, icon: "i")
    fillRect(canvas, 388, 356, 368, 1, color(0xffffff, 0.14))
    drawMenuRow(canvas, "Open in Codex", 356, 388, 432, highlighted: highlight > 0.35, icon: "C")
    drawMenuRow(canvas, "Services", 356, 440, 432, chevron: true, icon: "*")
    NSGraphicsContext.restoreGraphicsState()
}

func drawAccurateMenuRow(_ canvas: Canvas, _ text: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, highlighted: Bool = false, chevron: Bool = false, icon: String? = nil) {
    if highlighted {
        fillRound(canvas, x + 10, y - 3, w - 20, 40, 8, color(0x5c5c5c, 0.88))
    }
    if let icon {
        drawText(canvas, icon, x + 28, y + 4, 26, 26, size: 17, weight: .semibold, color: color(0xdde3ee), align: .center)
    }
    drawText(canvas, text, x + 66, y + 1, w - 112, 32, size: 20, weight: .medium, color: color(0xecf0f6))
    if chevron {
        drawText(canvas, ">", x + w - 44, y, 24, 32, size: 24, weight: .semibold, color: color(0xd7dbe3), align: .center)
    }
}

func drawSubmenuRow(_ canvas: Canvas, _ text: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, highlighted: Bool = false, icon: String) {
    if highlighted {
        fillRound(canvas, x + 10, y - 3, w - 20, 38, 8, color(0x0a84ff, 0.98))
    }
    drawText(canvas, icon, x + 30, y + 4, 26, 26, size: 18, weight: .semibold, color: color(0xf4f7ff), align: .center)
    drawText(canvas, text, x + 70, y + 1, w - 92, 32, size: 19, weight: .medium, color: color(0xf7f9ff))
}

func drawAccurateContextMenu(_ canvas: Canvas, alpha: CGFloat, quickActions: CGFloat, codexHighlight: CGFloat) {
    guard alpha > 0 else { return }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.cgContext.setAlpha(alpha)

    fillRound(canvas, 146, 58, 620, 600, 24, color(0x111315, 0.98), stroke: color(0x565c66, 0.78), lineWidth: 1.1)
    drawAccurateMenuRow(canvas, "Open in New Tab", 146, 86, 620, icon: "O")
    drawAccurateMenuRow(canvas, "Remove Download", 146, 130, 620, icon: "x")
    drawAccurateMenuRow(canvas, "Keep Downloaded", 146, 174, 620, icon: "v")
    fillRect(canvas, 178, 224, 556, 1, color(0xffffff, 0.14))
    drawAccurateMenuRow(canvas, "Move to Trash", 146, 246, 620, icon: "T")
    fillRect(canvas, 178, 296, 556, 1, color(0xffffff, 0.14))
    drawAccurateMenuRow(canvas, "Get Info", 146, 318, 620, icon: "i")
    drawAccurateMenuRow(canvas, "Rename", 146, 362, 620, icon: "R")
    drawAccurateMenuRow(canvas, "Compress \"codex-open-folder\"", 146, 406, 620, icon: "Z")
    drawAccurateMenuRow(canvas, "Duplicate", 146, 450, 620, icon: "+")
    drawAccurateMenuRow(canvas, "Make Alias", 146, 494, 620, icon: "A")
    drawAccurateMenuRow(canvas, "Quick Look", 146, 538, 620, icon: "Q")
    fillRect(canvas, 178, 586, 556, 1, color(0xffffff, 0.14))

    let qaAlpha = max(quickActions, codexHighlight)
    drawAccurateMenuRow(canvas, "Quick Actions", 146, 608, 620, highlighted: qaAlpha > 0.15, chevron: true, icon: "*")

    if quickActions > 0 {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(quickActions)
        fillRound(canvas, 760, 484, 406, 162, 20, color(0x111315, 0.98), stroke: color(0x565c66, 0.78), lineWidth: 1.1)
        drawSubmenuRow(canvas, "Open Folder in Cursor", 760, 510, 406, icon: "C")
        drawSubmenuRow(canvas, "Open Folder in VSCode", 760, 554, 406, icon: "V")
        drawSubmenuRow(canvas, "Open in Codex", 760, 598, 406, highlighted: codexHighlight > 0.2, icon: "C")
        NSGraphicsContext.restoreGraphicsState()
    }

    NSGraphicsContext.restoreGraphicsState()
}

func drawCodexWindow(_ canvas: Canvas, alpha: CGFloat) {
    guard alpha > 0 else { return }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.cgContext.setAlpha(alpha)
    fillRound(canvas, 820, 132, 326, 430, 34, color(0x151a24, 0.98), stroke: color(0x4c5364, 0.85), lineWidth: 1.2)
    drawCodexAppIcon(canvas, 886, 154, 194)
    drawText(canvas, "Codex", 842, 352, 282, 52, size: 46, weight: .heavy, color: color(0xffffff), align: .center)
    drawText(canvas, "Workspace opened", 856, 414, 254, 30, size: 22, weight: .semibold, color: color(0xcfd8ea), align: .center)
    fillRound(canvas, 864, 474, 238, 50, 14, color(0x273247, 0.92))
    drawText(canvas, "No npm. Just macOS.", 888, 488, 190, 22, size: 17, weight: .semibold, color: color(0xbfe4ff), align: .center)
    NSGraphicsContext.restoreGraphicsState()
}

func drawSocialCard(width: CGFloat, height: CGFloat) -> NSImage {
    let canvas = Canvas(width: width, height: height)
    canvas.image.lockFocus()

    let bg = NSGradient(colors: [color(0x090b10), color(0x161b25), color(0x10131b)])!
    bg.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 18)
    fillRound(canvas, 70, 50, 1140, 620, 36, color(0xffffff, 0.04), stroke: color(0xffffff, 0.08))
    drawText(canvas, "Right-click a folder.", 104, 74, 760, 66, size: 52, weight: .heavy, color: color(0xffffff))
    drawText(canvas, "Open in Codex.", 104, 140, 760, 66, size: 52, weight: .heavy, color: color(0xbfdcff))
    drawText(canvas, "A Finder Quick Action for Codex Desktop.", 108, 224, 650, 32, size: 22, weight: .medium, color: color(0xb7c1d2))

    fillRound(canvas, 104, 314, 456, 104, 18, color(0x111923, 0.98), stroke: color(0x526070, 0.75), lineWidth: 1.2)
    fillRound(canvas, 124, 336, 416, 60, 12, color(0x0a84ff, 0.92), stroke: color(0x92c9ff, 0.72), lineWidth: 1.2)
    drawFolderIcon(canvas, 146, 344, selected: true)
    drawText(canvas, "project-folder", 222, 354, 260, 34, size: 25, weight: .semibold, color: color(0xf7fbff))

    fillRound(canvas, 420, 272, 444, 288, 26, color(0x101316, 0.98), stroke: color(0x596170, 0.82), lineWidth: 1.2)
    drawMenuRow(canvas, "Open", 420, 308, 444, icon: "O")
    drawMenuRow(canvas, "Rename", 420, 360, 444, icon: "R")
    drawMenuRow(canvas, "Get Info", 420, 412, 444, icon: "i")
    fillRect(canvas, 452, 468, 380, 1, color(0xffffff, 0.14))
    drawMenuRow(canvas, "Open in Codex", 420, 500, 444, highlighted: true, icon: "C")

    drawCodexAppIcon(canvas, 930, 216, 254)
    drawText(canvas, "Codex", 894, 500, 326, 58, size: 52, weight: .heavy, color: color(0xffffff), align: .center)
    drawText(canvas, "Workspace opened", 904, 566, 306, 30, size: 22, weight: .semibold, color: color(0xcfd8ea), align: .center)

    canvas.image.unlockFocus()
    return canvas.image
}

func drawScene(frame: Int, width: CGFloat, height: CGFloat, poster: Bool = false) -> NSImage {
    let canvas = Canvas(width: width, height: height)
    canvas.image.lockFocus()

    let bg = NSGradient(colors: [color(0x0b0d12), color(0x161b24), color(0x0f1118)])!
    bg.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 18)
    fillRound(canvas, 72, 52, 1136, 616, 32, color(0xffffff, 0.035), stroke: color(0xffffff, 0.08))
    drawText(canvas, "Open folders in Codex from Finder", 100, 48, 780, 44, size: 34, weight: .bold, color: color(0xf7f9ff))
    drawText(canvas, "Finder Quick Actions > Open in Codex", 100, 92, 620, 28, size: 19, weight: .medium, color: color(0xaeb8c9))

    drawFinder(canvas)

    let menuAlpha = poster ? 1 : progress(frame, 18, 32)
    let menuFade = poster ? 1 : (1 - progress(frame, 108, 128))
    let quickActions = poster ? 1 : progress(frame, 58, 76)
    let highlight = poster ? 1 : progress(frame, 92, 110)
    drawAccurateContextMenu(canvas, alpha: menuAlpha * menuFade, quickActions: quickActions, codexHighlight: highlight)
    if !poster {
        drawCodexWindow(canvas, alpha: progress(frame, 118, 136))
    }

    let p1 = progress(frame, 0, 42)
    let p2 = progress(frame, 42, 82)
    let p3 = progress(frame, 82, 116)
    var cursorX = 250 + (704 - 250) * p1
    var cursorY = 218 + (626 - 218) * p1
    if frame > 42 {
        cursorX = 704 + (936 - 704) * p2
        cursorY = 626 + (618 - 626) * p2
    }
    if frame > 82 {
        cursorX = 936 + (982 - 936) * p3
        cursorY = 618 + (274 - 618) * p3
    }
    let click = max(progress(frame, 104, 112) * (1 - progress(frame, 114, 126)), 0)
    if !poster {
        drawCursor(canvas, x: cursorX, y: cursorY, click: click)
    }

    canvas.image.unlockFocus()
    return canvas.image
}

func writePNG(_ image: NSImage, _ path: String) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "RenderAssets", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try data.write(to: URL(fileURLWithPath: path))
}

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "media"
let frameDir = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "/private/tmp/open-in-codex-media-frames"

try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(atPath: frameDir, withIntermediateDirectories: true)

let socialCard = drawSocialCard(width: 1600, height: 900)
try writePNG(socialCard, "\(outputDir)/open-in-codex-twitter-card.png")
try writePNG(socialCard, "\(outputDir)/open-in-codex-card.png")
try writePNG(drawScene(frame: 118, width: 1280, height: 720, poster: true), "\(outputDir)/open-in-codex-demo-poster.png")

for frame in 0..<150 {
    let image = drawScene(frame: frame, width: 1280, height: 720)
    let path = "\(frameDir)/frame\(String(format: "%04d", frame)).png"
    try writePNG(image, path)
}

print("Rendered poster assets to \(outputDir)")
print("Rendered frames to \(frameDir)")
