# Opennote

AI-powered learning and note-taking app for iOS. The notebook that thinks with you.

## Setup

1. **Open the project**  
   Open `Opennote.xcodeproj` in Xcode (in the parent OpenNoteMVP folder).

2. **Run on Simulator**  
   Select an iPhone simulator (e.g. iPhone 15 Pro) and press Run (⌘R).

3. **Run on your iPhone**  
   - Connect your device
   - Select it as the run destination
   - In Xcode: **Signing & Capabilities** → select your **Development Team**
   - Trust the developer on device: Settings → General → VPN & Device Management

## Feynman AI (Optional)

To enable the Feynman AI tutor in journals:

1. Edit `Opennote/Config/OpenAIConfig.swift`
2. Replace `"YOUR_OPENAI_API_KEY"` with your OpenAI API key
3. Get a key at: https://platform.openai.com/api-keys

Without an API key, the app runs fully; Feynman will show an setup message when used.

## Flow

- **Splash** → Skip → **Onboarding** → Get Started → **Login** → Sign In → **Dashboard**
- Auth state persists across app launches
- **Sidebar**: New+, Search, Home, Inbox, Your Journals, Your Papers
- **Journal Editor**: Block-based editing, Ask Feynman, keyboard toolbar
- **Paper Editor**: LaTeX-capable text editor
