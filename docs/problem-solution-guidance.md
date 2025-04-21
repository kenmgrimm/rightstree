# Problem-Solution Guidance Feature Requirements

## Overview

The Problem-Solution Guidance feature is a core component of the patent service, designed to guide users through the process of articulating a clear technical problem and a corresponding solution suitable for a patent application. The feature leverages the OpenaiService to provide interactive, prompt-driven guidance, ensures all outputs are concise and in plain language, and stores key conversational context as standalone memory objects for future reference.

## Functional Requirements

### 1. Guided Discovery Process

- The service must initiate and maintain a structured dialogue with the user to:
  - Identify the technical area of interest.
  - Determine if the user has a product or service in mind.
  - Elicit a clear statement of the problem the user is trying to solve.
  - Ascertain whether the problem/solution relates to an existing patent application.
  - Guide the user to describe their proposed solution in detail.

- The service must use the following example prompts (or close variants) to guide the conversation:
  - For problem identification:
    - "What technical area are you interested in?"
    - "Do you have a product or service in mind?"
    - "What is the problem you are trying to solve?"
    - "Do you have an existing patent application that your problem/solution is attempting to address?"
  - For solution articulation:
    - "Describe to me the solution you are suggesting to address the problem."

- The service should not respond to or entertain user requests that are unrelated to the problem and solution discovery process.

- The service should be building up a patent application object that will be used to store the problem and solution as well as future claims, sections, and diagrams, etc.

### 2. Output Format

- The final output must include:
  - A clear problem statement (1-3 sentences, plain text).
  - A clear solution statement (1-3 sentences to a short paragraph, plain text).

### 3. OpenaiService Integration

- The OpenaiService must be called to generate prompts and process user responses.
- Responses from the OpenaiService must be streamed to the caller to ensure a responsive user experience.

### 4. Memory and Context Storage

- Key aspects of the conversation must be stored as memory objects in the database.
- Stored context should support both ongoing interaction (for context continuity) and later reference (for audit/history).

## Non-Functional Requirements

- The service must provide comprehensive debug logging to track the flow of execution and the state of the application.
- All code must follow best practices for maintainability and extensibility.
- The feature must be designed to allow for future expansion (e.g., additional guidance steps, support for other types of IP filings, support for future steps in the process like claims drafting and section generation, images and diagrams generation).

## Acceptance Criteria

- [ ] The service guides the user through problem and solution discovery using the specified prompts.
- [ ] The output includes both a problem and a solution statement in the required format.
- [ ] The service does not respond to off-topic user requests.  Or, if the user requests something that is not related to the problem and solution discovery process, the service should respond with a message that is appropriate and helpful to the user to guide them back to the problem and solution discovery process.
- [ ] All relevant conversational context is stored as a standalone memory object.
- [ ] Streaming of OpenaiService responses is implemented.
- [ ] Comprehensive debug logging is present throughout the code.

---

## Implementation Plan (Phased Sub-Stories)

### Phase 1: Core Guided Conversation
- Implement structured prompt flow for problem and solution discovery using OpenaiService.
- Restrict responses to only problem/solution-related requests.
- Output clear problem and solution statements.
- Add comprehensive debug logging for all interactions.

### Phase 2: Patent Application Object Foundation
- Introduce a patent application object to store problem, solution, and prepare for future claims/sections/diagrams.
- Persist this object through the session and associate it with the user.

### Phase 3: Context Memory Storage
- Store key aspects of the conversation as standalone memory objects in the database.
- Ensure stored context supports both ongoing and future reference.

### Phase 4: Streaming and User Guidance
- Stream OpenaiService responses to the caller for improved UX.
- Implement logic to handle off-topic user requests by providing helpful guidance back to the flow.

### Phase 5: Extensibility and Future Steps
- Refactor codebase for maintainability and extensibility.
- Prepare for additional steps: claims drafting, section generation, and image/diagram support.
- Document extension points and best practices for future contributors.

### Phase 6: Script Harness for CLI Interaction
- Develop a script harness to allow the service to be run from the command line.
- Support invocation via `rails runner` and/or standalone Ruby scripts.
- Enable developers and stakeholders to interactively test and demo the service outside of the main application.
- Provide documentation and example scripts for usage.
