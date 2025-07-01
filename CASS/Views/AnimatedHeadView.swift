import SwiftUI

struct AnimatedHeadView: View {
    @Binding var isSpeaking: Bool
    var personality: ChatViewModel.Personality
    
    // Animation properties
    @State private var mouthOffset: CGFloat = 0
    @State private var eyeBlinkLeft: Bool = false
    @State private var eyeBlinkRight: Bool = false
    
    // Timers for essential animations
    let speechTimer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    let blinkTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    // Skin and feature colors
    let skinBase = Color(red: 0.98, green: 0.85, blue: 0.75)
    let skinShadow = Color(red: 0.95, green: 0.82, blue: 0.72)
    let lipColor = Color(red: 0.85, green: 0.6, blue: 0.55)
    let eyeColor = Color(red: 0.35, green: 0.55, blue: 0.85)
    // Hair colors
    let gold = Color(red: 0.9, green: 0.7, blue: 0.3)
    let grey = Color(red: 0.7, green: 0.7, blue: 0.7)
    let red = Color(red: 0.8, green: 0.2, blue: 0.1)
    // Beard color (grey for mentor)
    let beardGrey = Color(red: 0.7, green: 0.7, blue: 0.7)
    // Mustache color (red for debator)
    let mustacheRed = Color(red: 0.8, green: 0.2, blue: 0.1)
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let centerX = width / 2
            let centerY = height / 2
            
            // Select hair color based on personality
            let hair: Color = {
                switch personality {
                case .mentor:
                    return grey
                case .debator:
                    return red
                default:
                    return gold
                }
            }()
            
            ZStack {
                // Moderately wavy hair style
                Group {
                    Path { path in
                        // Start at the bottom left, near the ear
                        path.move(to: CGPoint(x: centerX - 80, y: centerY - 25))

                        // Create more pronounced wavy curves for the left side
                        path.addCurve(
                            to: CGPoint(x: centerX - 60, y: centerY - 90),
                            control1: CGPoint(x: centerX - 95, y: centerY - 60),
                            control2: CGPoint(x: centerX - 80, y: centerY - 85)
                        )
                        
                        // Add a more pronounced wave
                        path.addCurve(
                            to: CGPoint(x: centerX - 40, y: centerY - 110),
                            control1: CGPoint(x: centerX - 45, y: centerY - 95),
                            control2: CGPoint(x: centerX - 35, y: centerY - 105)
                        )

                        // Continue with more waves across the top
                        path.addCurve(
                            to: CGPoint(x: centerX + 40, y: centerY - 110),
                            control1: CGPoint(x: centerX - 20, y: centerY - 115),
                            control2: CGPoint(x: centerX + 20, y: centerY - 115)
                        )
                        
                        path.addCurve(
                            to: CGPoint(x: centerX + 60, y: centerY - 90),
                            control1: CGPoint(x: centerX + 35, y: centerY - 105),
                            control2: CGPoint(x: centerX + 45, y: centerY - 95)
                        )

                        // Create the right side with matching waves
                        path.addCurve(
                            to: CGPoint(x: centerX + 85, y: centerY - 30),
                            control1: CGPoint(x: centerX + 80, y: centerY - 85),
                            control2: CGPoint(x: centerX + 95, y: centerY - 60)
                        )
                        
                        // Connect back along the hairline with a gentle curve
                        path.addLine(to: CGPoint(x: centerX + 80, y: centerY - 20))
                        path.addQuadCurve(
                            to: CGPoint(x: centerX - 80, y: centerY - 25),
                            control: CGPoint(x: centerX, y: centerY - 15)
                        )
                    }
                    .fill(hair)

                    // Add a highlight swoosh for the 3D emoji effect
                    Path { path in
                        path.move(to: CGPoint(x: centerX - 35, y: centerY - 95))
                        path.addCurve(
                            to: CGPoint(x: centerX + 35, y: centerY - 90),
                            control1: CGPoint(x: centerX - 5, y: centerY - 105),
                            control2: CGPoint(x: centerX + 15, y: centerY - 100)
                        )
                    }
                    .stroke(hair.opacity(0.5), style: StrokeStyle(lineWidth: 15, lineCap: .round))
                }

                // Brad Pitt's distinctive face shape
                Path { path in
                    // Strong forehead
                    path.move(to: CGPoint(x: centerX - 60, y: centerY - 70))
                    path.addCurve(
                        to: CGPoint(x: centerX + 60, y: centerY - 70),
                        control1: CGPoint(x: centerX - 30, y: centerY - 75),
                        control2: CGPoint(x: centerX + 30, y: centerY - 75)
                    )
                    // Defined cheekbone
                    path.addCurve(
                        to: CGPoint(x: centerX + 70, y: centerY + 20),
                        control1: CGPoint(x: centerX + 75, y: centerY - 40),
                        control2: CGPoint(x: centerX + 75, y: centerY - 10)
                    )
                    // Strong jawline
                    path.addCurve(
                        to: CGPoint(x: centerX, y: centerY + 70),
                        control1: CGPoint(x: centerX + 65, y: centerY + 50),
                        control2: CGPoint(x: centerX + 30, y: centerY + 70)
                    )
                    path.addCurve(
                        to: CGPoint(x: centerX - 70, y: centerY + 20),
                        control1: CGPoint(x: centerX - 30, y: centerY + 70),
                        control2: CGPoint(x: centerX - 65, y: centerY + 50)
                    )
                    path.addCurve(
                        to: CGPoint(x: centerX - 60, y: centerY - 70),
                        control1: CGPoint(x: centerX - 75, y: centerY - 10),
                        control2: CGPoint(x: centerX - 75, y: centerY - 40)
                    )
                }
                .fill(skinBase)

                // Mentor beard
                if personality == .mentor {
                    Path { path in
                        path.move(to: CGPoint(x: centerX - 30, y: centerY + 40))
                        path.addQuadCurve(to: CGPoint(x: centerX + 30, y: centerY + 40), control: CGPoint(x: centerX, y: centerY + 80))
                        path.addQuadCurve(to: CGPoint(x: centerX - 30, y: centerY + 40), control: CGPoint(x: centerX, y: centerY + 70))
                    }
                    .fill(beardGrey.opacity(0.7))
                }

                // Debator mustache
                if personality == .debator {
                    // Single curly mustache above the mouth
                    Path { path in
                        path.move(to: CGPoint(x: centerX - 35, y: centerY + 12))
                        path.addCurve(to: CGPoint(x: centerX - 10, y: centerY + 18), control1: CGPoint(x: centerX - 30, y: centerY + 2), control2: CGPoint(x: centerX - 18, y: centerY + 22))
                        path.addCurve(to: CGPoint(x: centerX + 10, y: centerY + 18), control1: CGPoint(x: centerX - 2, y: centerY + 14), control2: CGPoint(x: centerX + 2, y: centerY + 22))
                        path.addCurve(to: CGPoint(x: centerX + 35, y: centerY + 12), control1: CGPoint(x: centerX + 18, y: centerY + 22), control2: CGPoint(x: centerX + 30, y: centerY + 2))
                    }
                    .stroke(mustacheRed, lineWidth: 4)
                }

                // Facial features
                Group {
                    // Brad's blue eyes
                    Group {
                        // Left eye
                        Group {
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 28, height: eyeBlinkLeft ? 1 : 16)
                                .position(x: centerX - 25, y: centerY - 33)
                                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)

                            if !eyeBlinkLeft {
                                Circle()
                                    .fill(eyeColor)
                                    .frame(width: 12, height: 12)
                                    .position(x: centerX - 25, y: centerY - 33)

                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 6, height: 6)
                                    .position(x: centerX - 25, y: centerY - 33)

                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 4, height: 4)
                                    .position(x: centerX - 23, y: centerY - 35)
                            }
                        }

                        // Right eye
                        Group {
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 28, height: eyeBlinkRight ? 1 : 16)
                                .position(x: centerX + 25, y: centerY - 33)
                                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)

                            if !eyeBlinkRight {
                                Circle()
                                    .fill(eyeColor)
                                    .frame(width: 12, height: 12)
                                    .position(x: centerX + 25, y: centerY - 33)

                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 6, height: 6)
                                    .position(x: centerX + 25, y: centerY - 33)

                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 4, height: 4)
                                    .position(x: centerX + 27, y: centerY - 35)
                            }
                        }
                    }

                    // Characteristic nose
                    Path { path in
                        path.move(to: CGPoint(x: centerX - 2, y: centerY - 35))
                        path.addCurve(
                            to: CGPoint(x: centerX + 8, y: centerY - 5),
                            control1: CGPoint(x: centerX + 1, y: centerY - 25),
                            control2: CGPoint(x: centerX + 6, y: centerY - 15)
                        )
                        path.addCurve(
                            to: CGPoint(x: centerX, y: centerY + 8),
                            control1: CGPoint(x: centerX + 10, y: centerY + 2),
                            control2: CGPoint(x: centerX + 5, y: centerY + 8)
                        )
                        path.addCurve(
                            to: CGPoint(x: centerX - 8, y: centerY - 5),
                            control1: CGPoint(x: centerX - 5, y: centerY + 8),
                            control2: CGPoint(x: centerX - 10, y: centerY + 2)
                        )
                    }
                    .fill(skinShadow)

                    // Brad's distinctive mouth
                    Group {
                        // Upper lip
                        Path { path in
                            path.move(to: CGPoint(x: centerX - 15, y: centerY + 28))
                            path.addCurve(
                                to: CGPoint(x: centerX, y: centerY + 27),
                                control1: CGPoint(x: centerX - 10, y: centerY + 28),
                                control2: CGPoint(x: centerX - 5, y: centerY + 27)
                            )
                            path.addCurve(
                                to: CGPoint(x: centerX + 15, y: centerY + 28),
                                control1: CGPoint(x: centerX + 5, y: centerY + 27),
                                control2: CGPoint(x: centerX + 10, y: centerY + 28)
                            )
                        }
                        .stroke(lipColor, lineWidth: 1.5)
                        
                        // Lower lip
                        Path { path in
                            path.move(to: CGPoint(x: centerX - 15, y: centerY + 28))
                            path.addQuadCurve(
                                to: CGPoint(x: centerX + 15, y: centerY + 28),
                                control: CGPoint(x: centerX, y: centerY + 35 + (isSpeaking ? mouthOffset : 4))
                            )
                        }
                        .stroke(lipColor, lineWidth: 2)
                    }

                    // Strong eyebrows
                    Group {
                        // Left eyebrow
                        Path { path in
                            path.move(to: CGPoint(x: centerX - 40, y: centerY - 55))
                            path.addQuadCurve(
                                to: CGPoint(x: centerX - 15, y: centerY - 55),
                                control: CGPoint(x: centerX - 27, y: centerY - 58)
                            )
                        }
                        .stroke(hair, lineWidth: 3)

                        // Right eyebrow
                        Path { path in
                            path.move(to: CGPoint(x: centerX + 15, y: centerY - 55))
                            path.addQuadCurve(
                                to: CGPoint(x: centerX + 40, y: centerY - 55),
                                control: CGPoint(x: centerX + 27, y: centerY - 58)
                            )
                        }
                        .stroke(hair, lineWidth: 3)
                    }
                }
            }
        }
        .frame(width: 200, height: 250)
        // Essential animations only
        .onReceive(speechTimer) { _ in
            if isSpeaking {
                withAnimation(.easeInOut(duration: 0.15)) {
                    mouthOffset = CGFloat.random(in: 2...6)
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    mouthOffset = 0
                }
            }
        }
        .onReceive(blinkTimer) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                eyeBlinkLeft = true
                eyeBlinkRight = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    eyeBlinkLeft = false
                    eyeBlinkRight = false
                }
            }
        }
    }
}