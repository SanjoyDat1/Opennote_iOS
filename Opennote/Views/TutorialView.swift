import SwiftUI

/// Step-by-step tutorial explaining what OpenNote is. Skip skips the tutorial.
struct TutorialView: View {
    let onComplete: () -> Void
    
    private let pages: [TutorialPage] = [
        TutorialPage(
            icon: "paperplane.fill",
            iconColor: Color.opennoteCreamDark,  // Cream, not green
            title: "The notebook that thinks with you",
            body: "Opennote combines smart note-taking with AI-powered learning. Capture ideas, then deepen your understanding."
        ),
        TutorialPage(
            icon: "book.closed.fill",
            iconColor: Color.opennoteGreen,
            title: "Journals & Feynman AI",
            body: "Write in blocks—headings, lists, code. Ask Feynman any question and get explanations in plain language."
        ),
        TutorialPage(
            icon: "doc.text.fill",
            iconColor: Color.opennoteGreen,
            title: "Papers for LaTeX",
            body: "Compose academic papers and equations in LaTeX. Clean, focused writing for serious work."
        ),
        TutorialPage(
            icon: "tray.fill",
            iconColor: Color.opennoteGreen,
            title: "Inbox & Research",
            body: "Capture quick thoughts and research notes. Keep everything in one place."
        ),
        TutorialPage(
            icon: "sparkles",
            iconColor: Color.opennoteGreen,
            title: "You're ready",
            body: "Create journals and papers, ask Feynman to explain concepts, and build your knowledge base."
        )
    ]
    
    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            Color.opennoteCream
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        Haptics.notification(.success)
                        onComplete()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 17, weight: .medium, design: .default))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        TutorialPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                
                VStack(spacing: 24) {
                    PageIndicator(current: currentPage, total: pages.count)
                    
                    Button {
                        Haptics.selection()
                        if currentPage < pages.count - 1 {
                            withAnimation { currentPage += 1 }
                        } else {
                            onComplete()
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .font(.system(size: 17, weight: .semibold, design: .default))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.opennoteGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

struct TutorialPage {
    let icon: String
    let iconColor: Color
    let title: String
    let body: String
}

private struct TutorialPageView: View {
    let page: TutorialPage
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: page.icon)
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(page.iconColor)
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)
            
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                
                Text(page.body)
                    .font(.system(size: 17, design: .default))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }
}

private struct PageIndicator: View {
    let current: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.opennoteGreen : Color(.systemGray4))
                    .frame(width: index == current ? 10 : 8, height: index == current ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}

#Preview {
    TutorialView(onComplete: {})
}
