// app/javascript/controllers/patent_form_controller.js
//
// Stimulus controller for the patent application form
// Handles form validation, submission, and debug logging
//
// This controller is attached to the patent application form and provides:
// - Real-time validation of problem and solution fields
// - Submission handling with debug logging
// - Form state management

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["problem", "solution", "submitButton"]
  
  connect() {
    console.debug("[PatentFormController] Connected to form", this.element.id)
    this.validateForm()
  }
  
  // Validates the form fields and enables/disables the submit button
  validateForm() {
    const problemValid = this.problemTarget.value.trim().length > 0
    const solutionValid = this.solutionTarget.value.trim().length > 0
    const formValid = problemValid && solutionValid
    
    console.debug("[PatentFormController] Form validation:", {
      problemValid,
      solutionValid,
      formValid
    })
    
    this.submitButtonTarget.disabled = !formValid
  }
  
  // Logs the save action for debugging
  logSave() {
    console.debug("[PatentFormController] Saving patent application", {
      problem: this.problemTarget.value.substring(0, 50) + "...",
      solution: this.solutionTarget.value.substring(0, 50) + "..."
    })
  }
  
  // Handles form submission completion
  handleSubmit(event) {
    const success = !this.element.querySelector(".alert-danger")
    
    console.debug("[PatentFormController] Form submission completed", {
      success,
      response: event.detail.fetchResponse
    })
    
    if (success) {
      // Form was successfully submitted
      console.debug("[PatentFormController] Patent application saved successfully")
    }
  }
}
