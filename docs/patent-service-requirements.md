# Patent Service Requirements (AI-Driven)

## Purpose
Define the requirements for a Rails service object (PatentService) that leverages the OpenaiService to assist users in drafting patent applications, including claims, sections, and diagrams.

## Key Features

### 1. Problem-Solution Guidance
- Guide the user to articulate a clear problem and corresponding solution suitable for a patent.
- OpenaiService should be called to walk the user through the problem and solution discovery process.
- Example prompts that should be used to guide the user to identifying a clear problem include:
  - What technical area are you interested in?
  - Do you have a product or service in mind?
  - What is the problem you are trying to solve?
  - Do you have an existing patent application that your problem / solution is attempting to address?
- Example prompts that should be used to guide the user to identifying a clear solution include:
  - Describe to me the solution you are suggesting to address the problem.
- The output of this step should be a clear problem statement and a clear solution statement, both in plain text.  The problem should be 1-3 sentences, the solution should be 1-3 sentences to a short paragraph.
- The service should not entertain any chat requests by the user that are not related to the problem and solution discovery process.
- This service should stream responses from the OpenaiService to the caller
- A memory of key aspects of the conversation should be stored in the database for use as context during the interaction as well as for later reference. This memory should be a standalone object that could be associated with any type of AI interaction.

### 2. Claims Drafting
- Given a problem-solution pair, interactively guide the user through writing patent claims.
- Suggest claim structures and language based on best practices.
- Validate claims for clarity and coverage.

### 3. Section Generation
- Given the problem, solution, and claimset, generate the following patent sections:
  - **Abstract**
  - **Background**
  - **Summary**
  - **Drawings Description**
  - **Body (Detailed Description)**
- Use AI to ensure each section is well-structured and aligned with the provided claims.

### 4. Diagram/Flow Generation
- Given the claims, generate diagrams or flowcharts that illustrate the solution and claims.
- Output should be in a structured, editable format (e.g., SVG, pseudo-CAD, or text-based diagram markup) suitable for patent drawings.
- Avoid raster images; focus on vector or markup representations that are easy to edit and review.

### 5. Patentability Assessment
- Analyze the problem, solution, claims, and sections to:
  - Identify potential issues (e.g., lack of novelty, obviousness, clarity problems).
  - Provide feedback on whether the invention appears to be a strong patent candidate.
  - Suggest improvements or flag problematic areas for user review.

## Technical Requirements
- Implement as a Rails service object: `PatentService`
- All AI calls must go through the existing `OpenaiService` for API key management, logging, and error handling.
- Each function should be modular and testable.
- Add comprehensive debug logging for all major actions and AI interactions.
- Write RSpec specs for all major service functions.

## Next Steps
1. Design the `PatentService` interface and method signatures.
2. Implement initial scaffolding and connect to `OpenaiService`.
3. Write usage examples and specs for each function.
4. Document prompt strategies for each feature.
5. Review and iterate based on user feedback.
