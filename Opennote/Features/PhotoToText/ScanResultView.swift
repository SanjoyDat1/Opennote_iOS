import SwiftUI

struct ScanResultView: View {
    @Bindable var session: ScanSessionModel
    var onInsert: (String, InsertionMode) -> Void
    var onDismiss: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var editableText: String = ""
    @State private var showInsertOptions = false
    @State private var blinkOpacity: Double = 1.0
    @State private var showOriginalImage = false
    @State private var showDeleteImageAlert = false

    private var isFormatting: Bool {
        if case .formatting = session.phase { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if horizontalSizeClass == .regular {
                    HStack(spacing: 0) {
                        pane1
                        Rectangle().fill(Color(.separator)).frame(width: 1)
                        pane2
                    }
                } else {
                    TabView {
                        pane1
                            .tabItem { Text("Original") }
                        pane2
                            .tabItem { Text("Result") }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                }

                bottomBar
            }
            .navigationTitle("Scan Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert") {
                        showInsertOptions = true
                    }
                    .disabled(isFormatting)
                }
            }
            .confirmationDialog("Insert Options", isPresented: $showInsertOptions) {
                Button("Insert at Cursor") {
                    session.formattedText = editableText
                    onInsert(editableText, .atCursor(position: 0))
                }
                Button("Append to End") {
                    session.formattedText = editableText
                    onInsert(editableText, .appendToEnd)
                }
                Button("Replace Note") {
                    session.formattedText = editableText
                    onInsert(editableText, .replaceAll)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose where to insert the scanned text")
            }
        }
        .onAppear {
            editableText = session.formattedText
        }
        .onChange(of: session.formattedText) { _, newValue in
            editableText = newValue
        }
    }

    private var pane1: some View {
        VStack(spacing: 8) {
            if let img = session.capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text("Original")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var pane2: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        TextEditor(text: $editableText)
                            .font(.system(size: 17, weight: .regular, design: .default))
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(.primary)
                            .lineSpacing(8)
                            .frame(minHeight: 280)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .onChange(of: editableText) { _, newValue in
                                session.formattedText = newValue
                            }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                }
                .scrollIndicators(.visible)
                .background(
                    LinearGradient(
                        colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.opennoteGreen.opacity(0.18), lineWidth: 1)
                )
                .onChange(of: session.formattedText) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }

                if isFormatting {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: 20)
                        .opacity(blinkOpacity)
                        .padding(8)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: blinkOpacity)
                        .task(id: isFormatting) {
                            guard isFormatting else { return }
                            while !Task.isCancelled {
                                blinkOpacity = 0
                                try? await Task.sleep(nanoseconds: 250_000_000)
                                blinkOpacity = 1
                                try? await Task.sleep(nanoseconds: 250_000_000)
                            }
                        }
                }

                if session.capturedImage != nil {
                    VStack(spacing: 10) {
                        Button {
                            showOriginalImage = true
                        } label: {
                            Image(systemName: "photo")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.opennoteGreen)
                                .frame(width: 42, height: 42)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        Button {
                            showDeleteImageAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.red)
                                .frame(width: 42, height: 42)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.trailing, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .sheet(isPresented: $showOriginalImage) {
            NavigationStack {
                Group {
                    if let img = session.capturedImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    } else {
                        ContentUnavailableView("Image Removed", systemImage: "photo.slash")
                    }
                }
                .navigationTitle("Original Scan")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showOriginalImage = false }
                    }
                }
            }
        }
        .alert("Delete original image?", isPresented: $showDeleteImageAlert) {
            Button("Delete", role: .destructive) {
                session.capturedImage = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can keep the extracted text, but the source image will be removed from this scan.")
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            switch session.phase {
            case .enhancing:
                Text("Enhancing image…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .recognizing:
                Text("Reading text…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .formatting(let progress):
                VStack(spacing: 4) {
                    ProgressView(value: progress)
                    Text("Formatting with AI…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            case .reviewing:
                Text("Review and edit below, then tap Insert")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .failed(let msg):
                VStack(spacing: 8) {
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    if session.capturedImage != nil {
                        Button("Retry") {
                            Task {
                                await session.handleScannedImages([session.capturedImage!])
                            }
                        }
                    }
                }
            default:
                EmptyView()
            }

            if case .reviewing = session.phase, true {
                deepScanRow
            }
            if case .failed = session.phase, true {
                deepScanRow
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }

    private var deepScanRow: some View {
        HStack {
            Toggle("Deep Scan (skip on-device OCR)", isOn: Binding(
                get: { session.isDeepScan },
                set: { session.isDeepScan = $0 }
            ))
            if session.capturedImage != nil {
                Button("Re-scan") {
                    Task {
                        await session.handleScannedImages([session.capturedImage!])
                    }
                }
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }
}
