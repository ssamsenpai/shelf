import SwiftUI

/// List row: small rounded thumbnail, name, then quiet metadata trailing.
public struct AssetRow: View {
    private let name: String
    private let kindTitle: String
    private let symbol: String
    private let detail: String?
    private let thumbnail: Image?

    public init(
        name: String,
        kindTitle: String,
        symbol: String,
        detail: String?,
        thumbnail: Image?
    ) {
        self.name = name
        self.kindTitle = kindTitle
        self.symbol = symbol
        self.detail = detail
        self.thumbnail = thumbnail
    }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            ZStack {
                RoundedRectangle.shelf(Radius.small)
                    .fill(Color.shelfWell)

                if let thumbnail {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(2)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle.shelf(Radius.small))

            Text(name)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: Spacing.m)

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(kindTitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(kindTitle)")
    }
}
