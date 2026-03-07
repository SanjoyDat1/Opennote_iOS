# OpenNote MVP

<p align="center">
  <strong>The notebook that thinks with you.</strong>
</p>

OpenNote is an AI-first note-taking app for iOS that combines rich block-based journals, LaTeX papers, and an embedded AI tutor (Feynman) to help you learn and create.

---

## Features

### Journals
- **Block-based editor** — Paragraphs, headings, bullet lists, numbered lists, checklists, code blocks, callouts, math equations, and Desmos graphs
- **Ask Feynman** — Inline AI tutor that explains concepts, answers questions, and uses your notes as context
- **Slash commands** — Type `/` to insert blocks, format text, or trigger AI actions
- **Make flashcards** — AI generates flashcards from your notes
- **Practice problems** — AI generates practice problems with solutions
- **Photo to text** — Capture notes or whiteboards and extract text using AI vision
- **Long-press actions** — Rename, delete, or favorite journals from the sidebar or home view

### Papers
- **LaTeX editor** — Write and preview LaTeX with live PDF compilation
- **Ask Feynman** — AI-assisted LaTeX editing (add abstracts, fix formatting, rewrite sections)
- **Split view** — Code and PDF side-by-side on iPad
- **Export** — Compile to PDF, export to Markdown

### Design
- Clean, minimal UI with cream background and green accents
- Haptic feedback throughout
- Keyboard toolbar with Done button
- Responsive layout for iPhone and iPad

---

## Requirements

- **Xcode** 15.0+
- **iOS** 17.0+
- **Swift** 5.9+

---

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/SanjoyDat1/Opennote_iOS.git
cd Opennote_iOS
```

### 2. Open the project

Open `OpenNoteMVP.xcworkspace` or `Opennote.xcodeproj` in Xcode. The main app target is **Opennote**.

### 3. Configure OpenAI (for AI features)

1. Get an API key from [OpenAI Platform](https://platform.openai.com/api-keys)
2. Copy the example config and add your key:
   ```bash
   cp Opennote/Config/OpenAIConfig.example.swift Opennote/Config/OpenAIConfig.swift
   ```
3. Edit `Opennote/Config/OpenAIConfig.swift` and replace `YOUR_OPENAI_API_KEY` with your key.

> **Security:** `OpenAIConfig.swift` is in `.gitignore` and will never be committed. Your API key stays local.

### 4. Build and run

Select the **Opennote** scheme, choose a simulator or device, and run (⌘R).

---

## Project Structure

```
Opennote_iOS/
├── Opennote/                 # Main app
│   ├── App/                  # App entry point
│   ├── Config/               # API keys, configuration
│   ├── DesignSystem/         # Colors, typography, components
│   ├── Models/               # Journal, Paper, NoteBlock, etc.
│   ├── Services/             # OpenAI, code execution
│   ├── ViewModels/           # AppViewModel, JournalEditorViewModel
│   └── Views/                # All UI
│       ├── Editor/           # Block views, journal/paper editors
│       ├── Home/             # Home screen, cards, lists
│       ├── Inbox/
│       ├── Sidebar/
│       └── Upgrade/
├── docs/
│   └── ARCHITECTURE.md       # Internal architecture
└── README.md
```

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed internal structure.

---

## Architecture

- **SwiftUI** — Declarative UI
- **Observable** — State management (iOS 17+)
- **MVVM** — ViewModels for editor logic
- **UserDefaults** — Local persistence for journals and papers (MVP)
- **OpenAI API** — Streaming chat, vision, non-streaming completions

---

## Slash Commands

Type `/` in the journal editor to open the command palette:

| Section | Commands |
|---------|----------|
| **Formatting** | Text, Heading 1–3, Bullet list, Numbered list, Checklist, Quote, Divider |
| **Advanced** | Code block, LaTeX block, Graph (Desmos), Math equation |
| **Media** | Image, Photo to text |
| **AI** | Ask Feynman, Make flashcards, Make practice problems |

---

## Development

### Code formatting

The project includes a [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) config (`.swiftformat`). To format the codebase:

```bash
brew install swiftformat
swiftformat Opennote/
```

### Before pushing to GitHub

- Ensure `Opennote/Config/OpenAIConfig.swift` contains a placeholder (`YOUR_OPENAI_API_KEY`), not your real API key.
- Run the app locally with your key; never commit secrets.

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
