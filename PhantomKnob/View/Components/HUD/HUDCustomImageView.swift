import SwiftUI

public struct HUDCustomImageView: View {
    public let assets: HUDCustomImageAssets?

    public init(assets: HUDCustomImageAssets?) {
        self.assets = assets
    }

    public var body: some View {
        Group {
            if let path = assets?.backdropImagePath, let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}
