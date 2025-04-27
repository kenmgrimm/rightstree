// app/javascript/controllers/chat_form_controller.js
//
// Stimulus controller for the ChatGPT-style AI chat form
// Handles chat message submission, loading states, auto-expanding text area, and keyboard shortcuts
//
// This controller handles the chat form functionality:
// - Auto-expanding text area
// - Enter key to submit
// - Loading state during submission
// - Focus/blur effects for enhanced UI feedback
// - Comprehensive debug logging

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messageInput", "submitButton", "buttonText", "spinner"]
  
  connect() {
    console.debug("[ChatFormController] Connected")
    this.adjustHeight()
    this.messageInputTarget.focus()
  }
  
  // Auto-adjust the height of the text area as the user types
  adjustHeight() {
    const textarea = this.messageInputTarget
    
    // Reset height to auto to get the correct scrollHeight
    textarea.style.height = 'auto'
    
    // Set the height to match content (with a max height)
    const newHeight = Math.min(textarea.scrollHeight, 150)
    textarea.style.height = `${newHeight}px`
    
    console.debug("[ChatFormController] Adjusted textarea height", {
      scrollHeight: textarea.scrollHeight,
      newHeight: newHeight,
      content: textarea.value.length > 0 ? `${textarea.value.substring(0, 20)}...` : "(empty)"
    })
  }
  
  // Handle form submission start - show loading state
  handleSubmitStart() {
    const message = this.messageInputTarget.value
    console.debug("[ChatFormController] Submitting chat message", {
      messageLength: message.length,
      messagePreview: message.substring(0, 30) + (message.length > 30 ? '...' : ''),
      timestamp: new Date().toISOString()
    })
    
    // Show loading state
    this.submitButtonTarget.disabled = true
    this.buttonTextTarget.classList.add("opacity-0")
    this.spinnerTarget.classList.remove("d-none")
  }
  
  // Handle form submission end - reset form and loading state
  handleSubmitEnd(event) {
    console.debug("[ChatFormController] Chat message submission completed", {
      success: !event.detail.error,
      status: event.detail.fetchResponse?.response?.status,
      timestamp: new Date().toISOString()
    })
    
    // Reset form
    this.messageInputTarget.value = ""
    this.adjustHeight() // Reset height
    this.messageInputTarget.focus()
    
    // Reset loading state
    this.submitButtonTarget.disabled = false
    this.buttonTextTarget.classList.remove("opacity-0")
    this.spinnerTarget.classList.add("d-none")
  }
  
  // Handle keyboard events (Enter to send, Shift+Enter for new line)
  handleKeydown(event) {
    // Submit on Enter (without Shift)
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.element.requestSubmit()
      
      console.debug("[ChatFormController] Form submitted via Enter key", {
        timestamp: new Date().toISOString()
      })
    } else {
      console.debug("[ChatFormController] Key pressed", {
        key: event.key,
        shiftKey: event.shiftKey,
        timestamp: new Date().toISOString()
      })
    }
  }
  
  // Handle focus event - enhance the input appearance
  handleFocus() {
    console.debug("[ChatFormController] Input focused")
    this.element.querySelector('.chat-input-wrapper').style.boxShadow = "0 0 0 2px var(--primary-light), 0 4px 6px rgba(0, 0, 0, 0.1)"
    this.submitButtonTarget.style.transform = "scale(1.05)"
  }
  
  // Handle blur event - return to normal appearance
  handleBlur() {
    console.debug("[ChatFormController] Input blurred")
    this.element.querySelector('.chat-input-wrapper').style.boxShadow = ""
    this.submitButtonTarget.style.transform = "scale(1)"
  }
}
