# OpenNote MVC Architectural Audit

**Date:** 2026-02-24  
**Scope:** Full codebase audit for MVC pattern compliance  
**Mandate:** Reorganize responsibilities and move code — no rewrites, no UI changes, no behavior changes.

---

## Section 1: File-by-File Audit Report

### App / Entry Point

#### [OpennoteApp.swift]
- **Current layer:** View (app root)
- **Should be:** View (app root) — correctly minimal
- **Violations found:**
  - None. Properly injects AppViewModel and NotesStore via environment.
- **Action required:**
  - None. Move to `Supporting/` or keep in reorganized structure.

---

### Models / Entities (Plain Data)

#### [Journal.swift]
- **Current layer:** Model
- **Should be:** Model (Entities)
- **Violations found:** None.
- **Action required:** Move to `Models/Entities/Journal.swift`

#### [Paper.swift]
- **Current layer:** Model
- **Should be:** Model (Entities)
- **Violations found:** None.
- **Action required:** Move to `Models/Entities/Paper.swift`

#### [NoteBlock.swift]
- **Current layer:** Model
- **Should be:** Model (Entities)
- **Violations found:** None. Contains `toMarkdown` — acceptable as data transformation, not display formatting.
- **Action required:** Move to `Models/Entities/NoteBlock.swift`

#### [SlashCommand.swift]
- **Current layer:** Model
- **Should be:** Model (Entities)
- **Violations found:** None.
- **Action required:** Move to `Models/Entities/SlashCommand.swift`

#### [PaperTemplate.swift]
- **Current layer:** Model
- **Should be:** Model (Entities)
- **Violations found:** None.
- **Action required:** Move to `Models/Entities/PaperTemplate.swift`

#### [InsertionMode.swift]
- **Current layer:** Model
- **Should be:** Model (Entities)
- **Violations found:** None.
- **Action required:** Move to `Models/Entities/InsertionMode.swift`

---

### Models / Repositories (Persistence)

#### [NotesStore.swift]
- **Current layer:** Model (mixed — store + persistence)
- **Should be:** Model (Repositories)
- **Violations found:**
  - Direct UserDefaults read/write. This IS a repository but named "Store." Rename for clarity.
- **Action required:**
  - Rename to `NotesRepository.swift`, move to `Models/Repositories/`
  - Ensure all persistence for journals/papers goes through this class only.
  - Consider extracting JournalDTO/PaperDTO to separate file if needed.

#### [AppViewModel.swift]
- **Current layer:** Controller (auth, onboarding state) + persistence
- **Should be:** Split — `AuthController` + `SettingsRepository` (or keep as controller that uses a repository)
- **Violations found:**
  - **VIOLATION D (Inline Persistence):** Direct UserDefaults read/write in `persistState()`, `init()`. No repository.
  - Acts as both auth controller and settings persistor.
- **Action required:**
  - Create `SettingsRepository` in `Models/Repositories/` for onboarding, tutorial, auth flags.
  - Rename to `AuthController` (or `AppController`). Inject `SettingsRepository`. Controller calls repository for persist.
  - Move `OpennoteUser` to `Models/Entities/`.

#### [AppSettings.swift]
- **Current layer:** Model (settings + persistence)
- **Should be:** Model (Repositories) — wraps UserDefaults
- **Violations found:**
  - **VIOLATION D (Inline Persistence):** Direct UserDefaults in property didSet. Should go through a repository.
- **Action required:**
  - Create or extend `SettingsRepository` to wrap all UserDefaults. `AppSettings` becomes a facade or is merged into `SettingsRepository`.

---

### Models / Services

#### [OpenAIService.swift]
- **Current layer:** Model (Service)
- **Should be:** Model (Services)
- **Violations found:** None. Stateless, API-only. UIKit not imported.
- **Action required:** Move to `Models/Services/OpenAIService.swift`

#### [CodeExecutionService.swift]
- **Current layer:** Model (Service)
- **Should be:** Model (Services)
- **Violations found:** None. Stateless.
- **Action required:** Move to `Models/Services/CodeExecutionService.swift`

#### [VisionOCRService.swift]
- **Current layer:** Model (Service)
- **Should be:** Model (Services)
- **Violations found:** None. UIKit imported for UIImage — permitted as data type.
- **Action required:** Move to `Models/Services/VisionOCRService.swift`

#### [OpenAIVisionService.swift]
- **Current layer:** Model (Service)
- **Should be:** Model (Services)
- **Violations found:** None.
- **Action required:** Move to `Models/Services/OpenAIVisionService.swift`

#### [ImagePreprocessor.swift]
- **Current layer:** Model (Service)
- **Should be:** Model (Services)
- **Violations found:** None.
- **Action required:** Move to `Models/Services/ImagePreprocessor.swift`

---

### ViewModels (→ Controllers)

#### [JournalEditorViewModel.swift]
- **Current layer:** Controller (MVVM-named)
- **Should be:** Controller
- **Violations found:**
  - **VIOLATION C (Service in View):** ViewModel directly instantiates `OpenAIService.shared` and calls it. In MVC, the Controller MAY own/call services — this is actually correct for a Controller. The naming "ViewModel" is wrong.
  - No navigation logic — good.
- **Action required:**
  - Rename to `JournalEditorController.swift`, move to `Controllers/`
  - Behavior is correct for a Controller. Keep service calls here.

---

### Views (Screens & Components)

#### [RootView.swift]
- **Current layer:** View
- **Should be:** View (Screens)
- **Violations found:** None. Routing logic is view-level conditional render — acceptable.
- **Action required:** Move to `Views/Screens/RootView.swift`

#### [MainContainerView.swift]
- **Current layer:** View
- **Should be:** View (Screens)
- **Violations found:**
  - Directly calls `notesStore.addJournal`, `notesStore.updateJournal`, etc. In MVC, a Controller typically mediates. However, MainContainerView receives NotesStore via environment and forwards mutations — the parent could be argued as the controller. For consistency, a `HomeController` could own create/update/delete and MainContainerView would call `homeController.createJournal()`.
  - `createJournal()` / `createPaper()` contain `Haptics.impact` — cosmetic, acceptable.
- **Action required:**
  - Consider extracting `MainContainerController` (or `HomeController`) to own create/select/delete logic. Low priority — current pattern is acceptable if we consider the View as receiving store and calling methods; the store is the model gateway.
  - Move to `Views/Screens/MainContainerView.swift`

#### [HomeView.swift]
- **Current layer:** View
- **Should be:** View (Screens)
- **Violations found:** None. Receives data and callbacks. Pure presentation.
- **Action required:** Move to `Views/Screens/Home/HomeView.swift`

#### [SidebarView.swift]
- **Current layer:** View
- **Should be:** View (Components or Screens)
- **Violations found:** None.
- **Action required:** Move to `Views/Components/SidebarView.swift` or `Views/Screens/Sidebar/SidebarView.swift`

#### [InboxView.swift]
- **Current layer:** View
- **Should be:** View (Screens)
- **Violations found:** None (placeholder).
- **Action required:** Move to `Views/Screens/Inbox/InboxView.swift`

#### [JournalEditorView.swift]
- **Current layer:** View
- **Should be:** View (Screens)
- **Violations found:**
  - **VIOLATION A (Fat View):** `handleSlashCommandSelected` triggers `Task { await viewModel.generateFlashcards(blockId: newId) }` and `Task { await viewModel.generatePracticeProblems(...) }` — the Task is initiated from the View. The View is forwarding to the ViewModel (Controller). The actual async work is in the ViewModel. This is borderline: the View is starting a Task that calls the controller. Per strict MVC, the View should call `controller.requestFlashcards(blockId)` and the Controller owns the Task. Current pattern: View calls `Task { await viewModel.generate... }` — the Controller does the work; the View just kicks it off. Acceptable. The alternative is `onGenerate` closure from BlockRowView which already does `Task { await viewModel.generateFlashcards }` — so the flow is View → closure → ViewModel. That's fine.
  - `handleSlashCommandSelected` contains business logic (switch on cmd.id, insertBlockType). That logic could live in the Controller. The Controller could expose `handleSlashCommand(cmd, blockId)` and the View calls it.
- **Action required:**
  - Move slash command handling into `JournalEditorController` (e.g. `handleSlashCommand(_:blockId:)`). View calls controller. Low risk.
  - Move to `Views/Screens/Editor/JournalEditorView.swift`

#### [PaperEditorView.swift]
- **Current layer:** View
- **Should be:** View (Screens)
- **Violations found:**
  - **VIOLATION A (Fat View):** `compileAndPreview()` contains a `Task` that does `URLSession.shared.data(for: request)` — direct network call in the View. This must move to a Service (e.g. `LaTeXCompileService`) and a Controller (e.g. `PaperEditorController`) that owns the compile logic.
  - **VIOLATION A:** `PaperAISheet` contains `Task { await runAI() }` and `runAI()` directly calls `OpenAIService.shared.editLaTeX`. The View (sheet) is calling a service. Must move to Controller.
  - `convertJournalToLaTeX` — business logic (string escaping, template building) in View. Move to Controller or Model helper.
  - `saveContent` directly calls `notesStore.updatePaper`. The parent could be considered the controller; but PaperEditorView owns this. For consistency, a `PaperEditorController` should own save and compile.
- **Action required:**
  - Create `PaperEditorController` to own: compile, AI edit, save, convertJournalToLaTeX.
  - Create `LaTeXCompileService` in `Models/Services/` for URLSession compile call (or keep in a compile helper).
  - Extract `PaperAISheet` logic: View calls `controller.runAI(prompt)`; Controller calls OpenAIService, sets aiOutput/errorMessage.
  - Move to `Views/Screens/Editor/PaperEditorView.swift`

#### [BlockRowView.swift]
- **Current layer:** View
- **Should be:** View (Components)
- **Violations found:**
  - Dispatches to ViewModel for all operations. Good.
  - `runFeynman`, `generateFlashcards`, `generatePracticeProblems` are private wrappers that call viewModel. Fine.
  - Contains `Task { await runFeynman(...) }` in onRun closure — the closure is passed from View to AIPromptBlockView. The Task is in BlockRowView. The work is in viewModel. Acceptable.
- **Action required:** Move to `Views/Components/Editor/BlockRowView.swift`

#### [ParagraphBlockView.swift], [HeadingBlockView.swift], [BulletListBlockView.swift], [NumberedListBlockView.swift], [CodeCardBlockView.swift], [AIPromptBlockView.swift], [CalloutBlockView.swift], [TodoBlockView.swift], [DividerBlockView.swift], [GraphBlockView.swift], [MathBlockView.swift]
- **Current layer:** View
- **Should be:** View (Components)
- **Violations found:**
  - **CodeCardBlockView:** **VIOLATION A (Fat View):** `runCode()` is an async function in the View that calls `CodeExecutionService.execute` directly. The View owns a service call. Must move: View calls `onRun()` closure; BlockRowView passes `Task { await viewModel.runCodeBlock(...) }`. Create `runCodeBlock` in JournalEditorController that calls CodeExecutionService and updates block.
- **Action required:**
  - CodeCardBlockView: Add `onRun: () -> Void` (or `onRun: () async -> Void`). BlockRowView wires to `viewModel.runCodeBlock(blockId)`. JournalEditorController implements `runCodeBlock` using CodeExecutionService.
  - All others: Move to `Views/Components/Editor/`

#### [FlashcardBlockView.swift], [PracticeProblemsBlockView.swift]
- **Current layer:** View
- **Should be:** View (Components)
- **Violations found:** None. Receive `onGenerate` from parent; no direct service calls.
- **Action required:** Move to `Views/Components/Editor/`

#### [SlashCommandPaletteView.swift]
- **Current layer:** View
- **Should be:** View (Components)
- **Violations found:** None.
- **Action required:** Move to `Views/Components/Editor/SlashCommandPaletteView.swift`

#### [PhotoToTextView.swift]
- **Current layer:** View
- **Should be:** View (Components)
- **Violations found:**
  - **VIOLATION A (Fat View):** `extractText(from image: UIImage) async` directly calls `OpenAIService.shared.extractTextFromImage(data)`. View contains async business logic and service call.
- **Action required:**
  - PhotoToTextView should receive an `onExtractText: (UIImage) async -> String?` or similar from a Controller. Create `PhotoToTextController` that owns OpenAIService call. View calls controller.
  - Note: PhotoToTextView may be legacy — PhotoToTextButton + ScanSessionModel flow is the newer path. Confirm usage before refactoring.

#### [JournalSettingsSheet.swift], [PaperSettingsSheet.swift], [SettingsComponents.swift]
- **Current layer:** View
- **Should be:** View (Components or Screens)
- **Violations found:** None significant. May reference store/controller via params.
- **Action required:** Move to `Views/Components/Settings/` or appropriate folder.

#### [SplashView.swift], [LoginView.swift], [OnboardingView.swift], [TutorialView.swift], [AppLoadView.swift]
- **Current layer:** View
- **Should be:** View (Screens)
- **Violations found:**
  - **LoginView:** `performSignIn()` calls `appViewModel.signIn(user:)` — correct. Controller (AppViewModel) handles sign-in. Fine.
- **Action required:** Move to `Views/Screens/`

#### [UpgradeSheet.swift]
- **Current layer:** View
- **Should be:** View (Screens)
- **Violations found:** None.
- **Action required:** Move to `Views/Screens/Upgrade/UpgradeSheet.swift`

---

### Photo-to-Text Feature

#### [ScanSessionModel.swift]
- **Current layer:** Model (domain state + pipeline orchestration)
- **Should be:** Model
- **Violations found:**
  - Calls `ImagePreprocessor`, `VisionOCRService`, `OpenAIVisionService` directly — pipeline orchestration. This is business logic. Model can own domain state and coordinate services for a processing pipeline. However, `insertText(into:mode:)` mutates a string and performs `phase = .done` + `Task { self.reset() }` — the Task and MainActor call could be considered presentation concern. Minor.
  - **VIOLATION G (Navigation in Model):** No navigation. Good.
  - Does not import SwiftUI. Uses UIKit for UIImage only — permitted.
- **Action required:**
  - ScanSessionModel is acceptable as a Model that orchestrates the scan pipeline. Optionally extract pipeline orchestration to a `ScanPipelineService` that ScanSessionModel uses, keeping ScanSessionModel as state holder. Low priority.
  - Ensure no View types are referenced. Currently clean.

#### [ScanResultView.swift]
- **Current layer:** View
- **Should be:** View
- **Violations found:**
  - **VIOLATION A (Fat View):** `Task { await session.handleScannedImages([session.capturedImage!]) }` in Retry and Re-scan buttons. The View is triggering async work on the Model. Per Section 5, ScanResultView should not own async Tasks that call services. The Model (ScanSessionModel) does the work. The View is calling `session.handleScannedImages` — so the Model is doing the work, not the View calling a service directly. ScanSessionModel is the pipeline; the View triggers it. The violation is that the View owns the Task. The Controller (ScanController per spec) should own "retry" and "re-scan" and the View would call `scanController.retry()` or similar. Currently there is no ScanController.
  - Directly mutates `session.formattedText = editableText` before onInsert — coordination between editable state and session. Could be Controller responsibility.
- **Action required:**
  - Create `ScanController` per Section 5. ScanController owns ScanSessionModel, exposes `retry()`, `reScan()`. View calls controller. ScanResultView receives ScanController (or equivalent interface) and calls methods instead of `session.handleScannedImages`.

#### [PhotoToTextButton.swift]
- **Current layer:** View
- **Should be:** View
- **Violations found:**
  - **VIOLATION A (Fat View):** `Task { await session.handleScannedImages(newImages) }` in onChange(of: scannedImages). View triggers async Model method.
  - **VIOLATION C (Service in View):** Holds `@State private var session = ScanSessionModel()`. ScanSessionModel is a Model, not a service — acceptable. But the View orchestrates the flow: scanner, picker, result. Per Section 5, PhotoToTextButton should receive a ScanController and be a thin shell.
  - Contains logic for when to show scanner vs picker vs result, and calls `session.insertText` and `binding.wrappedValue = copy` for insertion. Mixed coordination.
- **Action required:**
  - Create `ScanController`. PhotoToTextButton receives ScanController via param or @EnvironmentObject. ScanController owns ScanSessionModel. PhotoToTextButton presents sheets and forwards events to controller.

#### [DocumentScannerView.swift]
- **Current layer:** View (UIKit wrapper)
- **Should be:** View
- **Violations found:** None. Camera capture UI.
- **Action required:** Move to `Views/Components/PhotoToText/` or `Features/PhotoToText/`

---

### Design System

#### [Colors.swift], [Typography.swift], [CardStyle.swift], [Haptics.swift], [Toast.swift], [KeyboardDismissAccessory.swift]
- **Current layer:** Supporting (view utilities)
- **Should be:** Supporting / Resources
- **Violations found:**
  - Colors imports SwiftUI (for Color). Permitted — Color is a view-layer data type.
- **Action required:** Move to `Supporting/` or `Resources/DesignSystem/`

---

### Config

#### [OpenAIConfig.swift] / [OpenAIConfig.example.swift]
- **Current layer:** Config
- **Should be:** Supporting
- **Violations found:** None.
- **Action required:** Move to `Supporting/` or `Resources/Config/`

---

## Section 2: Common Violation Patterns Present

| Violation | Description | Files Affected |
|-----------|-------------|----------------|
| **A — Fat View** | View contains async Task that calls service or triggers business logic | PhotoToTextView, PaperEditorView (PaperAISheet, compileAndPreview), CodeCardBlockView, ScanResultView, PhotoToTextButton |
| **B — God Model** | Model knows about navigation or view state | None identified |
| **C — Service in View** | View directly holds or calls a service | PhotoToTextView (OpenAIService), CodeCardBlockView (CodeExecutionService), PaperAISheet (OpenAIService) |
| **D — Inline Persistence** | UserDefaults/CoreData in View or Controller without Repository | AppViewModel, AppSettings, NotesStore (OK — is repository but named Store) |
| **E — Business Logic in View** | View makes business-rule decisions | JournalEditorView (slash command switch), PaperEditorView (convertJournalToLaTeX) |
| **F — Mixed Responsibility File** | View + business logic in same file | PaperEditorView (contains PaperAISheet with runAI), PhotoToTextButton (contains PhotoToTextSourceSheet, PhotoPickerView) |
| **G — Navigation in Model** | Navigation logic in Model/Service | None |

---

## Section 3: Refactor Plan

### Phase 1: Create Repositories & Extract Persistence

**CHANGE 1**
- **Files affected:** New `Models/Repositories/SettingsRepository.swift`, `AppViewModel.swift`
- **Type of change:** Create, Extract
- **Description:** Create SettingsRepository that wraps all UserDefaults for onboarding, tutorial, auth flags. AppViewModel (to be renamed AuthController) injects and uses it. Remove direct UserDefaults from AppViewModel.
- **Risk level:** Low
- **Rollback plan:** Revert AppViewModel to direct UserDefaults; delete SettingsRepository.

**CHANGE 2**
- **Files affected:** `NotesStore.swift` → `Models/Repositories/NotesRepository.swift`
- **Type of change:** Rename, Move
- **Description:** Rename NotesStore to NotesRepository. Move to Models/Repositories/. Update all references (OpennoteApp, MainContainerView, JournalEditorView, PaperEditorView, etc.).
- **Risk level:** Low
- **Rollback plan:** Rename back to NotesStore, revert moves.

### Phase 2: Create Controllers & Extract Service Calls from Views

**CHANGE 3**
- **Files affected:** `JournalEditorViewModel.swift` → `Controllers/JournalEditorController.swift`
- **Type of change:** Rename, Move
- **Description:** Rename to JournalEditorController. Move to Controllers/. Add runCodeBlock(blockId) that calls CodeExecutionService and updates block. Update JournalEditorView, BlockRowView references.
- **Risk level:** Low
- **Rollback plan:** Rename back, move back, revert runCodeBlock.

**CHANGE 4**
- **Files affected:** `CodeCardBlockView.swift`, `BlockRowView.swift`, `JournalEditorController.swift`
- **Type of change:** Extract
- **Description:** CodeCardBlockView receives onRun: () -> Void. BlockRowView passes closure that calls controller.runCodeBlock(blockId). Implement runCodeBlock in JournalEditorController using CodeExecutionService. Remove runCode() and CodeExecutionService usage from CodeCardBlockView.
- **Risk level:** Low
- **Rollback plan:** Restore runCode in CodeCardBlockView, remove runCodeBlock from controller.

**CHANGE 5**
- **Files affected:** New `Controllers/PaperEditorController.swift`, `PaperEditorView.swift`, New `Models/Services/LaTeXCompileService.swift`
- **Type of change:** Create, Extract
- **Description:** Create LaTeXCompileService for compile API call. Create PaperEditorController to own compileAndPreview, runAI (for PaperAISheet), saveContent, convertJournalToLaTeX. PaperEditorView calls controller methods. PaperAISheet receives controller or callbacks from controller.
- **Risk level:** Medium
- **Rollback plan:** Move logic back into PaperEditorView, delete new files.

**CHANGE 6**
- **Files affected:** `PhotoToTextView.swift`, New `Controllers/PhotoToTextLegacyController.swift`
- **Type of change:** Create, Extract
- **Description:** Create PhotoToTextLegacyController (or similar) that owns extractText(from:). PhotoToTextView receives controller, calls controller.extractText(image) instead of calling OpenAIService directly. Remove extractText and OpenAIService from PhotoToTextView.
- **Risk level:** Low (if PhotoToTextView is still used — verify first)
- **Rollback plan:** Restore extractText in PhotoToTextView.

**CHANGE 7**
- **Files affected:** New `Controllers/ScanController.swift`, `PhotoToTextButton.swift`, `ScanResultView.swift`, `ScanSessionModel.swift`
- **Type of change:** Create, Extract
- **Description:** Create ScanController as ObservableObject. It owns ScanSessionModel, OpenAIVisionService (or delegates to session). Exposes startScan(), retry(), reScan(), confirmInsert(mode:), cancelScan(). PhotoToTextButton and ScanResultView receive ScanController. They call controller methods instead of session.handleScannedImages directly. ScanSessionModel remains Model; Controller orchestrates.
- **Risk level:** High (Photo-to-Text is complex, multiple entry points)
- **Rollback plan:** Revert to PhotoToTextButton owning ScanSessionModel, ScanResultView calling session directly.

### Phase 3: Folder Reorganization

**CHANGE 8**
- **Files affected:** All Swift files
- **Type of change:** Move
- **Description:** Reorganize into Models/Entities/, Models/Repositories/, Models/Services/, Views/Components/, Views/Screens/, Controllers/, Resources/, Supporting/. Update Xcode project file references.
- **Risk level:** Medium (many file moves, pbxproj edits)
- **Rollback plan:** Revert directory structure and pbxproj.

**CHANGE 9**
- **Files affected:** DesignSystem files, Config files
- **Type of change:** Move
- **Description:** Move Colors, Typography, CardStyle, Haptics, Toast, KeyboardDismissAccessory to Supporting/ or Resources/DesignSystem/. Move OpenAIConfig to Supporting/.
- **Risk level:** Low
- **Rollback plan:** Move back.

### Phase 4: Cleanup & Final Verification

**CHANGE 10**
- **Files affected:** JournalEditorView, JournalEditorController
- **Type of change:** Extract
- **Description:** Move handleSlashCommandSelected logic (switch on cmd.id, insertBlockType) into JournalEditorController.handleSlashCommand(_:blockId:). JournalEditorView calls controller.
- **Risk level:** Low
- **Rollback plan:** Move logic back to View.

**CHANGE 11**
- **Files affected:** ARCHITECTURE_AUDIT.md
- **Type of change:** Update
- **Description:** Append Post-Refactor Sign-Off section after implementation and testing.
- **Risk level:** N/A

---

## Section 4: Implementation Order Summary

1. Create SettingsRepository, refactor AppViewModel
2. Rename NotesStore → NotesRepository
3. Rename JournalEditorViewModel → JournalEditorController, add runCodeBlock
4. Extract CodeCardBlockView service call to Controller
5. Create PaperEditorController, LaTeXCompileService, refactor PaperEditorView
6. Create PhotoToTextLegacyController (if PhotoToTextView used), refactor PhotoToTextView
7. Create ScanController, refactor PhotoToTextButton and ScanResultView
8. Move all files to new folder structure
9. Move DesignSystem and Config to Supporting/Resources
10. Extract slash command logic to JournalEditorController
11. Final verification and sign-off

---

## Section 5: Post-Refactor Sign-Off

*(To be completed after implementation)*

| Feature | Model | View | Controller | Tested |
|---------|-------|------|-------------|--------|
| Auth / Onboarding | SettingsRepository, OpennoteUser | LoginView, OnboardingView | AuthController | [ ] |
| Notes CRUD | NotesRepository, Journal, Paper | HomeView, SidebarView | MainContainer (or HomeController) | [ ] |
| Journal Editor | NoteBlock, NotesRepository | JournalEditorView, BlockRowView, block views | JournalEditorController | [ ] |
| Paper Editor | Paper, NotesRepository | PaperEditorView, PaperAISheet | PaperEditorController | [ ] |
| Code Execution | CodeExecutionService | CodeCardBlockView | JournalEditorController | [ ] |
| Photo-to-Text (Scan) | ScanSessionModel, VisionOCR, OpenAIVision | PhotoToTextButton, ScanResultView | ScanController | [ ] |
| Photo-to-Text (Legacy) | OpenAIService | PhotoToTextView | PhotoToTextLegacyController | [ ] |

---

*End of Audit. Do not implement until confirmation received.*
