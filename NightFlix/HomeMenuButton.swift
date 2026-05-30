import SwiftUI

struct HomeMenuButton: View {
    var foregroundColor: Color = NightFlixStyle.primaryTextColor
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Capsule()
                    .frame(width: 18, height: 2)
                Capsule()
                    .frame(width: 18, height: 2)
                Capsule()
                    .frame(width: 18, height: 2)
            }
            .foregroundStyle(foregroundColor)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open menu")
    }
}
