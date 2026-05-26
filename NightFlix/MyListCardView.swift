import SwiftUI

struct MyListCardView: View {
    let item: MyListItem
    let onSelect: () -> Void
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                onSelect()
            } label: {
                VStack(alignment: .leading, spacing: 9) {
                    ResponsivePosterImage(url: item.posterURL)

                    Text(item.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NightFlixStyle.primaryTextColor)
                        .lineLimit(2)
                        .frame(height: 38, alignment: .topLeading)

                    HStack(spacing: 6) {
                        if let year = item.year, !year.isEmpty {
                            Text(year)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.58))
                                .lineLimit(1)
                        }

                        Text(item.mediaType.displayName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.78))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(NightFlixStyle.fillColor(darkOpacity: 0.08), in: Capsule())
                    }
                    .frame(height: 22, alignment: .leading)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
                .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(NightFlixStyle.borderColor(darkOpacity: 0.07), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View details for \(item.title)")

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.72), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel("Remove \(item.title) from My List")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
