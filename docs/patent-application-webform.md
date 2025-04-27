# Feature Spec: Patent Application Web Form with Live AI Chat

## Overview
This feature provides a simple, interactive web form for users to define and refine a problem-solution pair for a patent application. The form includes a live AI chat box (powered by OpenAI via the Rails backend) and editable text areas for both the problem and solution. The user can modify the problem and solution at any time, and the AI chat can be used to guide, clarify, or critique the entries. The completed problem-solution pair is saved as a `patent_application` object in the database.

## Goals
- Enable users to interactively define a clear technical problem and solution.
- Provide real-time AI guidance and feedback via chat.
- Allow users to edit the problem and solution independently at any time.
- Persist the problem-solution pair as a `patent_application` in the backend.

## User Stories
- **As a user**, I want to describe a technical problem and solution, with guidance from an AI assistant, so that I can prepare a strong patent application.
- **As a user**, I want to edit the problem and solution fields at any time, so that I can refine my ideas iteratively.
- **As a user**, I want to chat with the AI to get feedback, clarifications, or suggestions, so that my problem and solution are as clear and patentable as possible.
- **As a user**, I want to save my problem-solution pair to the database as a `patent_application`, so that I can retrieve and work on it later.

## Functional Requirements

### 1. Web Form UI
- Display a live AI chat box on the page (right or bottom panel).
- Display two text areas labeled "Problem" and "Solution".
- Both text areas are always editable by the user.
- Show a "Save" button to persist the current problem/solution to the backend.
- Show a "Submit to AI" button to send the current state (problem, solution, chat history) to the backend for AI feedback.
- Display the AI's responses in the chat box in real time.
- Indicate when the AI is processing (loading spinner or similar).

### 2. AI Chat Integration
- Messages typed into the chat box are POSTed to a Rails endpoint (e.g., `/patent_applications/ai_chat`).
- The backend maintains the chat history and context, sends messages to OpenAI, and returns the AI's response.
- The AI can reference the current problem and solution in its responses.
- The chat history is displayed in the UI, with clear distinction between user and AI messages.

### 3. Problem/Solution Editing
- The user can edit the problem and solution text areas at any time, regardless of chat state.
- Changes to the problem/solution are reflected in the backend only when the user clicks "Save".
- The AI chat can suggest edits, but the user is always in control of the final text.

### 4. Persistence
- When the user clicks "Save", the problem and solution (and optionally the chat history) are saved as a `patent_application` object in the database.
- The backend provides endpoints to create, update, and retrieve `patent_application` objects.

### 5. Validation & UX
- Both problem and solution fields must be non-empty to save.
- Show validation errors if the user tries to save an incomplete application.
- The UI should be simple, modern, and responsive.

## API Endpoints (Sample)
- `POST /patent_applications` — Create a new patent application.
- `PUT /patent_applications/:id` — Update an existing patent application.
- `GET /patent_applications/:id` — Retrieve a patent application.
- `POST /patent_applications/ai_chat` — Send a chat message and state to the AI.

## Data Model
- `patent_application`:
  - `id`: integer
  - `problem`: text
  - `solution`: text
  - `chat_history`: jsonb (optional, for replay/context)
  - `user_id`: integer (optional, if authentication is present)
  - `created_at`, `updated_at`

## Acceptance Criteria
- [ ] User can edit problem and solution at any time.
- [ ] User can chat with AI and see responses in real time.
- [ ] AI can reference the current problem/solution in its guidance.
- [ ] Saving persists the problem/solution as a `patent_application`.
- [ ] Validation prevents saving incomplete applications.
- [ ] UI is clear, modern, and responsive.

## Future Enhancements
- Support for attaching claims, diagrams, or additional metadata.
- User authentication and multi-application management.
- Version history for problem/solution edits.
- Export to PDF or patent application template.
