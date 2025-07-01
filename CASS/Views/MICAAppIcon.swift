import SwiftUI

struct MICAAppIcon: View {
    var body: some View {
        ZStack {
            Color.orange
            Text("MICA")
                .font(.system(size: 400, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0)) // iOS blue
                .minimumScaleFactor(0.01)
                .lineLimit(1)
                .padding(.horizontal, 40)
        }
        .frame(width: 1024, height: 1024)
    }
}

#Preview {
    MICAAppIcon()
} 