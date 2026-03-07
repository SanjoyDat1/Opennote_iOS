# OpenNote MVP – Architecture

This document describes the internal architecture of the OpenNote app and documents every source file.

---

## Project Structure

```
OpenNoteMVP/
├── Opennote/                         # Main app target
│   ├── App/
│   │   └── OpennoteApp.swift
│   ├── Config/
│   │   ├── OpenAIConfig.example.swift
│   │   └── OpenAIConfig.swift        # Gitignored – copy from example
│   ├── DesignSystem/
│   │   ├── Colors.swift
│   │   ├── Typography.swift
│   │   ├── CardStyle.swift
│   │   ├── Haptics.swift
│   │   └── Toast.swift
│   ├── Models/
│   │   ├── Journal.swift
│   │   ├── Paper.swift
│   │   ├── NoteBlock.swift
│   │   ├── NotesStore.swift
│   │   ├── PaperTemplate.swift
│   │   ├── AppSettings.swift
│   │   └── SlashCommand.swift
│   ├── Services/
│   │   ├── OpenAIService.swift
│   │   └── CodeExecutionService.swift
│   ├── ViewModels/
│   │   ├── AppViewModel.swift
│   │   └── JournalEditorViewModel.swift
│   └── Views/
│       ├── SplashView.swift
│       ├── LoginView.swift
│       ├── OnboardingView.swift
│       ├── RootView.swift
│       ├── MainContainerView.swift
│       ├── AppLoadView.swift
│       ├── TutorialView.swift
│       ├── Home/
│       │   └── HomeView.swift
│       ├── Sidebar/
│       │   └── SidebarView.swift
│       ├── Inbox/
│       │   └── InboxView.swift
│       ├── Editor/
│       │   ├── JournalEditorView.swift
│       │   ├── PaperEditorView.swift
│       │   ├── BlockRowView.swift
│       │   ├── ParagraphBlockView.swift
│       │   ├── HeadingBlockView.swift
│       │   ├── BulletListBlockView.swift
│       │   ├── NumberedListBlockView.swift
│       │   ├── CodeCardBlockView.swift
│       │   ├── AIPromptBlockView.swift
│       │   ├── CalloutBlockView.swift
│       │   ├── TodoBlockView.swift
│       │   ├── DividerBlockView.swift
│       │   ├── GraphBlockView.swift
│       │   ├── MathBlockView.swift
│       │   ├── FlashcardBlockView.swift
│       │   ├── PracticeProblemsBlockView.swift
│       │   ├── SlashCommandPaletteView.swift
│       │   ├── PhotoToTextView.swift
│       │   ├── JournalSettingsSheet.swift
│       │   ├── PaperSettingsSheet.swift
│       │   └── SettingsComponents.swift
│       └── Upgrade/
│           └── UpgradeSheet.swift
├── OpenNoteClinical/                 # Separate clinical variant (Supabase, RAG)
└── docs/
    └── ARCHITECTURE.md
```

---

## File Reference (Opennote Target)

### App
| File | Purpose |
|------|---------|
| `OpennoteApp.swift` | `@main` entry point. Injects `AppViewModel` and `NotesStore` via `@Environment`. Sets preferred color scheme. |

### Config
| File | Purpose |
|------|---------|
| `OpenAIConfig.example.swift` | Template with placeholder API key. Copy to `OpenAIConfig.swift` and add your key. |
| `OpenAIConfig.swift` | **Gitignored.** Holds OpenAI API key and model name. |

### DesignSystem
| File | Purpose |
|------|---------|
| `Colors.swift` | Hex color definitions: `opennoteCream`, `opennoteGreen`, `opennoteLightGreen`, `opennoteCreamDark`. |
| `Typography.swift` | View modifiers: `opennoteMajorHeader()`, `opennoteSectionHeader()`, `opennoteBody()`. |
| `CardStyle.swift` | `OpennoteCardModifier` and `opennoteCard()` for white cards with shadow. |
| `Haptics.swift` | `Haptics.impact()`, `Haptics.selection()` for tactile feedback. |
| `Toast.swift` | Toast notification utilities. |

### Models
| File | Purpose |
|------|---------|
| `Journal.swift` | `Journal` model: `id`, `title`, `lastEdited`, `isFavorite`. |
| `Paper.swift` | `Paper` model: `id`, `title`, `lastEdited`, `content`, `isFavorite`. |
| `NoteBlock.swift` | `NoteBlock` and `BlockType`: paragraph, heading, lists, code, AI prompt, flashcard, practice problems, graph, math, callout, todo, divider. `FlashcardItem`, `PracticeProblemItem`, `TodoItem`. Markdown export. |
| `NotesStore.swift` | `@Observable` store. UserDefaults persistence for journals and papers. CRUD, `pendingBlocksForJournalId` for cloning. |
| `PaperTemplate.swift` | Default LaTeX template for new papers. |
| `AppSettings.swift` | App-wide settings (e.g. proactive suggestions, frequency). |
| `SlashCommand.swift` | `SlashCommand` model and `SlashCommandSection`. Defines all `/` commands (formatting, advanced, media, AI, journals). |

### Services
| File | Purpose |
|------|---------|
| `OpenAIService.swift` | OpenAI REST client. Streaming chat, LaTeX edit, image-to-text (vision), flashcard/practice generation. High `max_tokens` to avoid cut-off. |
| `CodeExecutionService.swift` | Runs user code (e.g. Python) for code blocks. |

### ViewModels
| File | Purpose |
|------|---------|
| `AppViewModel.swift` | Auth state, current user, sign in/out. |
| `JournalEditorViewModel.swift` | Block CRUD, insert/delete/reorder, AI generation (Feynman, flashcards, practice problems), markdown export. |

### Views
| File | Purpose |
|------|---------|
| `SplashView.swift` | Animated splash with paper plane and "Opennote" text. |
| `LoginView.swift` | Google sign-in, welcome copy. |
| `OnboardingView.swift` | First-run onboarding flow. |
| `RootView.swift` | Routes: Splash → Onboarding/Login → Main. |
| `MainContainerView.swift` | Home + sidebar overlay + navigation to Journal/Paper editors. |
| `AppLoadView.swift` | Minimal load screen when re-opening app. |
| `TutorialView.swift` | Tutorial carousel. |
| `Home/HomeView.swift` | Grid/list of journals and papers. Create, select, delete, rename, favorite. Filter (All/Shared/Owned). |
| `Sidebar/SidebarView.swift` | User profile, Search, Home, Inbox, Your Journals, Your Papers. Create, "...more", long-press context menu. |
| `Inbox/InboxView.swift` | Inbox placeholder. |
| `Editor/JournalEditorView.swift` | Block editor. Slash commands, Ask Feynman, flashcards, practice problems, photo-to-text. Start-with buttons. |
| `Editor/PaperEditorView.swift` | LaTeX editor + PDF preview. Split view on iPad. Ask Feynman sheet. Compile, settings. |
| `Editor/BlockRowView.swift` | Dispatches to correct block view by `blockType`. Context menu (delete). |
| `Editor/ParagraphBlockView.swift` | TextField for paragraph. Slash-command detection. Multiline support. |
| `Editor/HeadingBlockView.swift` | Editable heading (H1–H3). |
| `Editor/BulletListBlockView.swift` | Bullet list with add/remove items. |
| `Editor/NumberedListBlockView.swift` | Numbered list with add/remove items. |
| `Editor/CodeCardBlockView.swift` | Code block with language picker, stdin/stdout, run button. |
| `Editor/AIPromptBlockView.swift` | Ask Feynman block. TextField + run button. Scrollable response area. |
| `Editor/CalloutBlockView.swift` | Quote/callout block. |
| `Editor/TodoBlockView.swift` | Checklist with checkboxes. |
| `Editor/DividerBlockView.swift` | Horizontal divider. |
| `Editor/GraphBlockView.swift` | Desmos graph expression input. |
| `Editor/MathBlockView.swift` | LaTeX math block. |
| `Editor/FlashcardBlockView.swift` | AI-generated flashcards. Swipeable cards, flip animation. |
| `Editor/PracticeProblemsBlockView.swift` | AI-generated practice problems. Expandable Q&A rows. |
| `Editor/SlashCommandPaletteView.swift` | Scrollable `/` command palette. Sections, filter, icons. |
| `Editor/PhotoToTextView.swift` | Photo picker + AI vision to extract text. Inserts result into journal. |
| `Editor/JournalSettingsSheet.swift` | Journal settings: export, clone, delete. |
| `Editor/PaperSettingsSheet.swift` | Paper settings: Ask Feynman, notes-to-PDF, compile, export, clone, delete. |
| `Editor/SettingsComponents.swift` | Reusable settings UI (e.g. frequency, integrations). |
| `Upgrade/UpgradeSheet.swift` | Upgrade/paywall sheet. |

---

## Data Flow

1. **NotesStore** – Single source of truth for journals and papers. Persisted via UserDefaults.
2. **JournalEditorViewModel** – Holds blocks in memory. Blocks are not persisted (MVP). Cloning uses `pendingBlocksForJournalId`.
3. **OpenAIService** – Called from ViewModels. Responses stream into blocks or sheets. High token limits (8K–16K) to avoid cut-off.
4. **Slash commands** – Typing `/` in a paragraph triggers `SlashCommandPaletteView`. Selection inserts blocks or opens sheets.

---

## Key Patterns

- **SwiftUI + @Observable** – ViewModels and stores use `@Observable` for reactive updates.
- **Environment injection** – `NotesStore`, `AppViewModel` passed via `.environment()`.
- **Block-based editor** – Each block type has a dedicated view. `BlockRowView` switches on `block.blockType`.
- **Streaming AI** – `streamChat` returns `AsyncThrowingStream<String, Error>`. ViewModel consumes and appends to a paragraph block.

---

## Dependencies

- **Swift 5.9+**, **iOS 17+**
- **OpenAI API** (REST) – Feynman, LaTeX edit, vision, flashcards, practice problems
- **PhotosUI** – Photo picker for photo-to-text
- No external Swift packages in the MVP target
