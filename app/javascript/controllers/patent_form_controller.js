// app/javascript/controllers/patent_form_controller.js
//
// Stimulus controller for the patent application form
// Handles form validation, submission, and debug logging
//
// This controller is attached to the patent application form and provides:
// - Real-time validation of problem and solution fields
// - Enhanced UI feedback with focus/blur effects
// - Submission handling with debug logging
// - Form state management

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["problem", "solution", "submitButton", "buttonText", "spinner"]
  
  connect() {
    console.debug("[PatentFormController] Connected to form", this.element.id)
    this.validateForm()
  }
  
  // Handle field focus - enhance the input appearance
  handleFieldFocus(event) {
    console.debug("[PatentFormController] Field focused", event.target.name)
    event.target.style.boxShadow = "0 0 0 0.25rem rgba(0, 102, 255, 0.15)"
    event.target.style.borderColor = "var(--primary-color)"
  }
  
  // Handle field blur - return to normal appearance
  handleFieldBlur(event) {
    console.debug("[PatentFormController] Field blurred", event.target.name)
    event.target.style.boxShadow = ""
    event.target.style.borderColor = ""
    
    // Validate form on blur
    this.validateForm()
  }
  
  // Validates the form fields and enables/disables the submit button
  validateForm() {
    const problemField = this.element.querySelector('#patent_application_problem')
    const solutionField = this.element.querySelector('#patent_application_solution')
    
    const problemValid = problemField && problemField.value.trim().length > 0
    const solutionValid = solutionField && solutionField.value.trim().length > 0
    const formValid = problemValid && solutionValid
    
    console.debug("[PatentFormController] Form validation:", {
      problemValid,
      solutionValid,
      formValid
    })
    
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !formValid
    }
  }
  
  // Handle form submission start
  handleSubmitStart() {
    console.debug("[PatentFormController] Form submission started")
    
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
    }
    
    if (this.hasButtonTextTarget) {
      this.buttonTextTarget.classList.add("opacity-0")
    }
    
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("d-none")
    }
  }
  
  // Handles form submission completion
  handleSubmitEnd(event) {
    const success = !this.element.querySelector(".alert-danger")
    
    console.debug("[PatentFormController] Form submission completed", {
      success,
      response: event.detail.fetchResponse
    })
    
    if (this.hasButtonTextTarget) {
      this.buttonTextTarget.classList.remove("opacity-0")
    }
    
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add("d-none")
    }
    
    if (success) {
      // Form was successfully submitted
      console.debug("[PatentFormController] Patent application saved successfully")
    } else {
      // Re-enable the submit button if there was an error
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false
      }
    }
  }
}
