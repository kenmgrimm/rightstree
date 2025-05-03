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
  static targets = ["form", "title", "problem", "solution", "submitButton", "buttonText", "spinner", "savedText"]
  
  connect() {
    console.debug("[PatentFormController] Connected to form", this.element.id)
    
    // First initialize change tracking to set original values
    this.initializeChangeTracking()
    
    // Set initial button state - should be disabled by default
    if (this.hasSubmitButtonTarget) {
      // Check if there are any changes already (e.g., when returning to a form with unsaved changes)
      const hasChanges = this.hasChanges()
      
      // Set initial button state - disabled by default unless there are changes
      this.submitButtonTarget.disabled = !hasChanges
      
      // Apply visual styling for disabled state
      if (!hasChanges) {
        this.submitButtonTarget.classList.add("opacity-50")
        this.submitButtonTarget.classList.add("cursor-not-allowed")
        
        // Set button text to "Saved" if the form has been saved before
        if (this.hasButtonTextTarget && this.element.dataset.persisted === "true") {
          this.buttonTextTarget.innerHTML = '<i class="bi bi-check-circle me-2"></i>Saved'
        }
      }
      
      // Debug logging
      console.debug("[PatentFormController] Initial button state:", {
        hasChanges,
        buttonDisabled: this.submitButtonTarget.disabled,
        persisted: this.element.dataset.persisted
      })
    }
    
    // Run full validation
    this.validateForm()
  }
  
  // Initialize change tracking
  initializeChangeTracking() {
    // Store original values
    this.originalValues = {
      title: this.titleTarget.value.trim(),
      problem: this.problemTarget.value.trim(),
      solution: this.solutionTarget.value.trim()
    }
    
    // Log the original values for debugging
    console.debug("[PatentFormController] Initialized change tracking with original values:", {
      title: this.originalValues.title.substring(0, 20) + (this.originalValues.title.length > 20 ? '...' : ''),
      problem: this.originalValues.problem.substring(0, 20) + (this.originalValues.problem.length > 20 ? '...' : ''),
      solution: this.originalValues.solution.substring(0, 20) + (this.originalValues.solution.length > 20 ? '...' : '')
    })
    
    // We're now using Stimulus actions instead of event listeners
    // See the data-action attributes in the HTML template
  }
  
  // Handle field input events via Stimulus actions
  handleFieldInput(event) {
    const fieldName = event.target.name || event.target.id || 'unknown'
    const fieldValue = event.target.value.trim()
    
    // Determine which field changed
    let originalValue = ''
    if (event.target === this.titleTarget) {
      originalValue = this.originalValues.title
    } else if (event.target === this.problemTarget) {
      originalValue = this.originalValues.problem
    } else if (event.target === this.solutionTarget) {
      originalValue = this.originalValues.solution
    }
    
    // Log detailed change information
    console.debug("[PatentFormController] Field input detected:", {
      field: fieldName,
      from: originalValue,
      to: fieldValue,
      changed: originalValue !== fieldValue
    })
    
    // Enable the button immediately if there's a change
    if (this.hasSubmitButtonTarget) {
      const hasChanges = this.hasChanges()
      console.debug("[PatentFormController] Form has changes:", hasChanges)
      
      if (hasChanges) {
        // Enable the button if there are changes
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.classList.remove("opacity-50")
        this.submitButtonTarget.classList.remove("cursor-not-allowed")
        
        if (this.hasButtonTextTarget) {
          this.buttonTextTarget.innerHTML = '<i class="bi bi-save me-2"></i>Save'
        }
      } else {
        // Disable the button if there are no changes
        this.submitButtonTarget.disabled = true
        this.submitButtonTarget.classList.add("opacity-50")
        this.submitButtonTarget.classList.add("cursor-not-allowed")
        
        if (this.hasButtonTextTarget) {
          this.buttonTextTarget.innerHTML = '<i class="bi bi-check-circle me-2"></i>Saved'
        }
      }
    }
    
    // Update overall form state
    this.validateForm()
  }
  
  // Keep the old handleChange method for backward compatibility
  handleChange(event) {
    // Just delegate to the new method
    this.handleFieldInput(event)
  }
  
  // Update button state and text based on changes
  updateButtonState() {
    const hasChanges = this.hasChanges()
    
    // Update button text
    if (this.hasButtonTextTarget) {
      const buttonText = hasChanges ? "Save" : "Saved"
      this.buttonTextTarget.innerHTML = hasChanges ? 
        '<i class="bi bi-save me-2"></i>Save' : 
        '<i class="bi bi-check-circle me-2"></i>Saved'
    }
    
    // Update button state
    if (this.hasSubmitButtonTarget) {
      if (hasChanges) {
        // Enable the button if there are changes
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.classList.remove("opacity-50")
        this.submitButtonTarget.classList.remove("cursor-not-allowed")
      } else {
        // Disable the button if there are no changes
        this.submitButtonTarget.disabled = true
        this.submitButtonTarget.classList.add("opacity-50")
        this.submitButtonTarget.classList.add("cursor-not-allowed")
      }
    }
  }
  
  // Check if any field has changed from original values
  hasChanges() {
    return this.titleTarget.value.trim() !== this.originalValues.title ||
           this.problemTarget.value.trim() !== this.originalValues.problem ||
           this.solutionTarget.value.trim() !== this.originalValues.solution
  }
  
  // Handle field focus - enhance the input appearance
  handleFieldFocus(event) {
    const field = event.target
    field.classList.add("shadow-sm")
    field.style.borderColor = "var(--primary-color)"  
  }
  
  // Handle field blur - return to normal appearance
  handleFieldBlur(event) {
    const field = event.target
    field.classList.remove("shadow-sm")
    field.style.borderColor = ""
    
    // Validate the field
    this.validateForm()
  }
  
  // Validate title field
  validateTitle(event) {
    const titleField = this.titleTarget
    const titleValue = titleField.value.trim()
    
    // Simple validation - title must not be empty
    if (titleValue.length === 0) {
      titleField.classList.add("is-invalid")
      console.debug("[PatentFormController] Title validation failed: empty title")
    } else {
      titleField.classList.remove("is-invalid")
      console.debug("[PatentFormController] Title validation passed")
    }
    
    this.validateForm()
  }
  
  // Validates the form fields and enables/disables the submit button
  validateForm() {
    // Check if any field has changed from its original value
    const hasChanges = this.hasChanges()
    
    // Enable the button if ANY field has changed - this is the key change
    if (this.hasSubmitButtonTarget) {
      // Enable button when any changes exist
      this.submitButtonTarget.disabled = !hasChanges
      
      // Update visual state
      if (hasChanges) {
        // When changes exist, enable the button and show active styling
        this.submitButtonTarget.classList.remove("opacity-50")
        this.submitButtonTarget.classList.remove("cursor-not-allowed")
        
        // Update button text to show Save
        if (this.hasButtonTextTarget) {
          this.buttonTextTarget.innerHTML = '<i class="bi bi-save me-2"></i>Save'
        }
      } else {
        // When no changes, disable button and show inactive styling
        this.submitButtonTarget.classList.add("opacity-50")
        this.submitButtonTarget.classList.add("cursor-not-allowed")
        
        // Update button text to show Saved when no changes
        if (this.hasButtonTextTarget) {
          this.buttonTextTarget.innerHTML = '<i class="bi bi-check-circle me-2"></i>Saved'
        }
      }
      
      // Add debug logging
      console.debug("[PatentFormController] Form validation:", {
        titleChanged: this.titleTarget.value.trim() !== this.originalValues.title,
        problemChanged: this.problemTarget.value.trim() !== this.originalValues.problem,
        solutionChanged: this.solutionTarget.value.trim() !== this.originalValues.solution,
        hasChanges: hasChanges,
        buttonDisabled: this.submitButtonTarget.disabled
      })
    }
  }
  
  // Handle form submission start
  handleSubmitStart(event) {
    console.debug("[PatentFormController] Form submission started")
    
    // Disable form inputs during submission
    this.element.querySelectorAll("input, textarea").forEach(field => {
      field.disabled = true
    })
    
    // Update button appearance
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("opacity-50")
      this.submitButtonTarget.classList.add("cursor-not-allowed")
    }
    
    if (this.hasButtonTextTarget) {
      this.buttonTextTarget.classList.add("opacity-0")
    }
  }
  
  // Handle form submission end
  handleSubmitEnd(event) {
    // Check if the response was successful (200 OK)
    const responseOK = event.detail.fetchResponse.response.ok
    // Also check for absence of error messages in the form
    const noFormErrors = !this.element.querySelector(".alert-danger")
    // Combined success check
    const success = responseOK && noFormErrors
    
    console.debug("[PatentFormController] Form submission completed", {
      responseStatus: event.detail.fetchResponse.response.status,
      responseOK,
      noFormErrors,
      success
    })
    
    // Re-enable form inputs
    this.element.querySelectorAll("input, textarea").forEach(field => {
      field.disabled = false
    })
    
    // Hide spinner and show button text
    if (this.hasButtonTextTarget) {
      this.buttonTextTarget.classList.remove("opacity-0")
    }
    
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add("d-none")
    }
    
    if (success) {
      // Update original values after successful save
      this.originalValues = {
        title: this.titleTarget.value.trim(),
        problem: this.problemTarget.value.trim(),
        solution: this.solutionTarget.value.trim()
      }
      
      console.debug("[PatentFormController] Updated original values after save:", {
        title: this.originalValues.title.substring(0, 20) + (this.originalValues.title.length > 20 ? '...' : ''),
        problem: this.originalValues.problem.substring(0, 20) + (this.originalValues.problem.length > 20 ? '...' : ''),
        solution: this.originalValues.solution.substring(0, 20) + (this.originalValues.solution.length > 20 ? '...' : '')
      })
      
      // Flash a success notification
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.classList.add("btn-success")
        this.submitButtonTarget.classList.remove("btn-primary")
        this.submitButtonTarget.disabled = true // Ensure button is disabled
        
        setTimeout(() => {
          this.submitButtonTarget.classList.remove("btn-success")
          this.submitButtonTarget.classList.add("btn-primary")
          this.updateButtonState()
        }, 1500) // Return to normal state after 1.5 seconds
      }
      
      // Feedback is now handled through flash messages at the top of the page
      console.debug("[PatentFormController] Form submitted successfully, feedback shown via flash message")
      
      // Show saved text if available
      if (this.hasSavedTextTarget) {
        this.savedTextTarget.classList.remove("d-none")
        setTimeout(() => {
          this.savedTextTarget.classList.add("d-none")
        }, 3000) // Hide after 3 seconds
      }
      
      // Form was successfully submitted
      console.debug("[PatentFormController] Patent application saved successfully")
    } else {
      // If there was an error, keep the button enabled
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.classList.remove("opacity-50")
        this.submitButtonTarget.classList.remove("cursor-not-allowed")
      }
      
      if (this.hasButtonTextTarget) {
        this.buttonTextTarget.innerHTML = '<i class="bi bi-save me-2"></i>Save'
      }
      
      console.debug("[PatentFormController] Form submission failed")
    }
  }
}
