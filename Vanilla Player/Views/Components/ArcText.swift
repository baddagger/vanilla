import SwiftUI

struct ArcText: View {
    let text: String
    let radius: CGFloat
    let startAngle: Angle
    let spacing: CGFloat // Approximate width per character (in degrees)

    // Optional: Closure for styling the text (e.g., font, color)
    var configure: ((Text) -> Text)?

    var body: some View {
        ZStack {
            ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                let charIndex = CGFloat(index)
                // Calculate the angle for this specific character
                // We add the startAngle to the relative position
                let angle =
                    startAngle + Angle(degrees: Double(charIndex * spacing))

                (configure?(Text(String(char))) ?? Text(String(char)))
                    .background(
                        GeometryReader { _ in
                            Color
                                .clear // Use this if you want to calculate exact widths dynamically
                        },
                    )
                    // 1. Move the character to the top of the circle (radius distance)
                    .offset(y: -radius)
                    // 2. Rotate it to the correct angle along the circle
                    .rotationEffect(angle)
            }
        }
    }
}

#Preview {
    ArcText(
        text: "VOLUME",
        radius: 50,
        startAngle: .degrees(50),
        spacing: 20,
        configure: { view in
            view.font(.system(size: 20))
        },
    )
    .frame(width: 100, height: 100)
    .padding()
}
