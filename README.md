# OpenNote Clinical

AI-first clinical note-taking app for iOS/iPadOS. Embeds a contextual AI tutor for cardiology and radiology workflows.

## Phase 1: Foundation & Auth ✓

### Setup

1. **Open the project**  
   Open `OpenNoteClinical.xcodeproj` in Xcode.

2. **Configure Supabase**  
   Edit `OpenNoteClinical/Config/SupabaseConfig.swift`:
   - Replace `YOUR_PROJECT_REF` with your Supabase project reference
   - Replace `YOUR_ANON_KEY` with your Supabase anon/public key  
   (Project Settings → API in the Supabase Dashboard)

3. **Run the database migration**  
   In Supabase Dashboard → SQL Editor, run the contents of `supabase/migrations/001_notes_schema.sql`.

4. **Enable Auth**  
   In Supabase Dashboard → Authentication:
   - Enable **Email** provider
   - Adjust email templates if desired

### What's implemented

- SwiftUI app with Swift 5.9+ and iOS 17+
- Supabase Swift SDK (Auth) via SPM
- SwiftData models: `Note`, `LocalUser`
- `AuthViewModel` with sign in, sign up, sign out
- Login/signup screen aligned with Apple HIG
- Root routing between Auth and Dashboard
- SQL migration for `notes` table with RLS

### Verification

After setup:

1. Build and run on simulator or device
2. Sign up with an email and password
3. Confirm you can sign in and see the Dashboard
4. Use **Sign Out** and confirm you return to the login screen

### Phase 2: Block Editor ✓

Implemented:
- **NoteViewModel** – block CRUD, insert heading/paragraph/bullet/code/AI, reindex
- **NoteEditorView** – ScrollView + LazyVStack of blocks, title editing
- **Block views** – Paragraph, Heading (H1–H3), Bullet list, Numbered list, Code card, AI prompt
- **Focus & return** – Return on paragraph/heading inserts new paragraph below; Return on last list item inserts paragraph below
- **Context toolbar** – Keyboard toolbar with H1, H2, H3, Bullet, 1., Code, AI
- **Delete block** – Long-press/context menu
- **Dashboard** – Notes list, create note, navigate to editor, delete notes
- **List “Add item”** – Bullet/numbered lists support adding items via “Add item”

### Phase 3: AI Clinical Co-Pilot ✓

Implemented:
- **Context Engine** – `NoteViewModel.blocksToMarkdown()` converts blocks to Markdown for AI context
- **OpenAIService** – Streaming chat completions via REST (gpt-4o-mini)
- **System Prompt** – Clinical Co-Pilot for cardiology/radiology, DICOM/ECG structuring, clarifying questions
- **AI Sidebar** – `.inspector` (sheet on iPhone, sidebar on iPad) with chat history
- **Inline AI Block** – Run button streams response into a new paragraph block below
- **Config** – `OpenAIConfig.swift` for API key

**Setup:** Add your OpenAI API key in `OpenNoteClinical/Config/OpenAIConfig.swift`.

### Phase 4: Semantic Search (RAG) ✓

Implemented:
- **pgvector** – `002_pgvector_embeddings.sql`: vector extension, `note_embeddings` table, ivfflat index
- **Embeddings** – `OpenAIService.embed()` using text-embedding-3-small (1536 dimensions)
- **Sync + embed** – `NoteSyncService` syncs notes to Supabase and stores embeddings via `upsert_note_embedding` RPC
- **Semantic search** – `SemanticSearchService` embeds the query and calls `search_notes_by_embedding` RPC (cosine similarity)
- **Global search bar** – Dashboard `.searchable()` with semantic search on submit
- **Debounced sync** – Sync on save (2s debounce) and immediate sync when closing the editor

**Setup:**
1. Run `supabase/migrations/002_pgvector_embeddings.sql` in Supabase SQL Editor.
2. Enable the `vector` extension in Supabase → Database → Extensions if needed.
