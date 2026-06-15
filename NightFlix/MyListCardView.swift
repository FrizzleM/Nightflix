import SwiftUI

struct MyListCardView: View {
    let item: MyListItem
    let onSelect: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            NightflixPoster(url: item.posterURL)
                .contentShape(Rectangle())
        }
        .buttonStyle(NightflixPressableStyle())
        .overlay(alignment: .topTrailing) {
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(.black.opacity(0.7), in: Circle())
                    .overlay { Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .padding(6)
            .accessibilityLabel("Remove \(item.title) from Watch Later")
        }
        .accessibilityLabel("View details for \(item.title)")
    }
}
