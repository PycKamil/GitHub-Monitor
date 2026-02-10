import SwiftUI

struct AppBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.09, blue: 0.12),
                        Color(red: 0.05, green: 0.06, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                BlurBackground(material: .hudWindow)
                    .opacity(0.25)

                RadialGradient(
                    colors: [
                        Color(red: 0.36, green: 0.55, blue: 0.95).opacity(0.45),
                        Color(red: 0.10, green: 0.12, blue: 0.18).opacity(0.0)
                    ],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: max(size.width, size.height) * 0.7
                )
                .blendMode(.screen)

                RadialGradient(
                    colors: [
                        Color(red: 0.22, green: 0.32, blue: 0.55).opacity(0.35),
                        Color.clear
                    ],
                    center: .bottomLeading,
                    startRadius: 40,
                    endRadius: max(size.width, size.height) * 0.55
                )
                .blendMode(.screen)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.6),
                        Color.black.opacity(0.15),
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.multiply)

                Color.white.opacity(0.03)
                    .blendMode(.softLight)
            }
        }
        .ignoresSafeArea()
    }
}

struct AppBackground_Previews: PreviewProvider {
    static var previews: some View {
        AppBackground()
    }
}
