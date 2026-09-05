import SwiftUI

struct RuntimeLogoView: View {
    @Environment(\.colorScheme) private var colorScheme
    let scope: RuntimeScope
    let size: CGFloat

    var body: some View {
        Group {
            if let image = RuntimeLogo.image(for: scope) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSystemName)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.18)
                    .foregroundStyle(.secondary)
                    .background(FixedVisualPalette.controlFill(colorScheme))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(4, size * 0.22), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: max(4, size * 0.22), style: .continuous)
                .strokeBorder(FixedVisualPalette.cardStroke(colorScheme), lineWidth: 0.7)
        )
        .accessibilityHidden(true)
    }

    private var fallbackSystemName: String {
        switch scope {
        case .codex:
            return "terminal"
        case .claudeCode:
            return "curlybraces"
        }
    }
}

private enum RuntimeLogo {
    static func image(for scope: RuntimeScope) -> NSImage? {
        let name: String
        switch scope {
        case .codex:
            name = "codex-color"
        case .claudeCode:
            name = "claudecode-color"
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
