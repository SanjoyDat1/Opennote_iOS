import SwiftUI

struct InboxView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.opennoteCream
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Inbox")
                        .opennoteMajorHeader()
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, height: 80)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    Text("No notifications")
                        .font(.system(size: 17, weight: .medium, design: .default))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    InboxView(isPresented: .constant(true))
}
