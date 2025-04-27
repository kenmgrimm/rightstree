// app/javascript/controllers/ai_suggestions_controller.js
//
// Stimulus controller for handling AI suggestions
// Manages accepting problem and solution suggestions from the AI
//
// This controller is attached to the AI suggestions panel and provides:
// - Accepting problem suggestions
// - Accepting solution suggestions
// - Comprehensive debug logging

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["acceptProblemBtn", "acceptSolutionBtn", "problemDebug", "solutionDebug"]
  static values = {
    problem: String,
    solution: String
  }
  
  connect() {
    console.debug("[AISuggestionsController] Connected to AI suggestions panel", {
      hasProblem: this.hasProblemValue,
      hasSolution: this.hasSolutionValue
    })
  }
  
  // Accept the AI's problem suggestion
  acceptProblem() {
    console.debug("[AISuggestionsController] Accepting problem suggestion:", this.problemValue)
    
    // Find the problem textarea in the form
    const problemTextarea = document.querySelector('textarea[name="patent_application[problem]"]')
    
    if (problemTextarea) {
      // Store the original value for logging
      const originalValue = problemTextarea.value
      
      // Update the textarea with the suggested problem
      problemTextarea.value = this.problemValue
      
      // Trigger input event to validate the form
      problemTextarea.dispatchEvent(new Event('input', { bubbles: true }))
      
      // Log the change
      console.debug("[AISuggestionsController] Updated problem field", {
        from: originalValue,
        to: this.problemValue
      })
      
      // Show debug message
      if (this.hasProblemDebugTarget) {
        this.problemDebugTarget.textContent = "Suggestion applied at " + new Date().toLocaleTimeString()
      }
    } else {
      console.error("[AISuggestionsController] Could not find problem textarea")
    }
  }
  
  // Accept the AI's solution suggestion
  acceptSolution() {
    console.debug("[AISuggestionsController] Accepting solution suggestion:", this.solutionValue)
    
    // Find the solution textarea in the form
    const solutionTextarea = document.querySelector('textarea[name="patent_application[solution]"]')
    
    if (solutionTextarea) {
      // Store the original value for logging
      const originalValue = solutionTextarea.value
      
      // Update the textarea with the suggested solution
      solutionTextarea.value = this.solutionValue
      
      // Trigger input event to validate the form
      solutionTextarea.dispatchEvent(new Event('input', { bubbles: true }))
      
      // Log the change
      console.debug("[AISuggestionsController] Updated solution field", {
        from: originalValue,
        to: this.solutionValue
      })
      
      // Show debug message
      if (this.hasSolutionDebugTarget) {
        this.solutionDebugTarget.textContent = "Suggestion applied at " + new Date().toLocaleTimeString()
      }
    } else {
      console.error("[AISuggestionsController] Could not find solution textarea")
    }
  }
}
