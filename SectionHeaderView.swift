import SwiftUI

struct SectionHeaderView: View {
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(NightFlixStyle.accentColor)
                .frame(width: 4, height: 28)

            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(NightFlixStyle.primaryTextColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
