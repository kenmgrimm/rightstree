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
    if (!message.trim()) return
    
    console.debug("[ChatFormController] Submitting chat message", {
      messageLength: message.length,
      messagePreview: message.substring(0, 30) + (message.length > 30 ? '...' : ''),
      timestamp: new Date().toISOString()
    })
    
    // No longer adding user message here - handled by server via Turbo Streams
    
    // Add loading indicator for AI response
    this.addLoadingIndicator()
    
    // Show loading state on button
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
    
    // Remove loading indicator
    this.removeLoadingIndicator()
    
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
    this.messageInputTarget.parentElement.classList.remove("shadow")
    this.messageInputTarget.parentElement.classList.add("shadow-sm")
  }
  
  // Add user message immediately to the chat
  addUserMessage(message) {
    console.debug("[ChatFormController] Adding user message to chat", {
      messageLength: message.length,
      timestamp: new Date().toISOString()
    })
    
    // Get both mobile and desktop chat containers
    const mobileChatMessages = document.getElementById('mobile_chat_messages')
    const desktopChatMessages = document.getElementById('desktop_chat_messages')
    
    if (!mobileChatMessages && !desktopChatMessages) {
      console.error("[ChatFormController] Could not find any chat messages container")
      return
    }
    
    const timestamp = Math.floor(Date.now() / 1000)
    const messageId = `message_${Math.random().toString(36).substring(2, 10)}`
    
    const messageHTML = `
      <div class="message mb-4 d-flex user-message justify-content-end" id="${messageId}" data-timestamp="${new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}">
        <div class="message-content p-3 rounded-3 shadow-sm text-white" style="max-width: 85%; background-color: var(--primary-color);">
          <div class="message-body">
            <p class="mb-1" style="color: white;">${this.escapeHTML(message)}</p>
          </div>
          <div class="message-footer d-flex justify-content-between align-items-center mt-2">
            <small class="opacity-75" style="color: rgba(255,255,255,0.8);">${new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}</small>
            <small class="opacity-75" style="color: rgba(255,255,255,0.8);">You</small>
          </div>
        </div>
        <div class="message-avatar ms-3 flex-shrink-0">
          <div class="avatar bg-white text-primary border rounded-circle d-flex align-items-center justify-content-center" style="width: 38px; height: 38px;">
            <i class="bi bi-person"></i>
          </div>
        </div>
      </div>
    `
    
    // Add message to both containers
    if (mobileChatMessages) {
      mobileChatMessages.insertAdjacentHTML('beforeend', messageHTML)
      mobileChatMessages.scrollTop = mobileChatMessages.scrollHeight
    }
    
    if (desktopChatMessages) {
      desktopChatMessages.insertAdjacentHTML('beforeend', messageHTML)
      desktopChatMessages.scrollTop = desktopChatMessages.scrollHeight
    }
  }
  
  // Add loading indicator while waiting for AI response
  addLoadingIndicator() {
    console.debug("[ChatFormController] Adding loading indicator")
    
    // Get both mobile and desktop chat containers
    const mobileChatMessages = document.getElementById('mobile_chat_messages')
    const desktopChatMessages = document.getElementById('desktop_chat_messages')
    
    if (!mobileChatMessages && !desktopChatMessages) {
      console.error("[ChatFormController] Could not find any chat messages container")
      return
    }
    
    const loadingId = 'ai_loading_indicator'
    
    // Remove any existing loading indicator
    const existingIndicator = document.getElementById(loadingId)
    if (existingIndicator) {
      existingIndicator.remove()
    }
    
    const loadingHTML = `
      <div class="message mb-4 d-flex ai-message" id="${loadingId}">
        <div class="message-avatar me-3 flex-shrink-0">
          <div class="avatar text-white rounded-circle d-flex align-items-center justify-content-center" style="width: 38px; height: 38px; background: linear-gradient(135deg, var(--primary-color), var(--accent-color));">
            <i class="bi bi-robot"></i>
          </div>
        </div>
        <div class="message-content p-3 rounded-3 shadow-sm" style="max-width: 85%; background-color: var(--surface-color);">
          <div class="message-body d-flex align-items-center">
            <div class="typing-indicator">
              <span class="dot"></span>
              <span class="dot"></span>
              <span class="dot"></span>
            </div>
          </div>
        </div>
      </div>
    `
    
    // Add loading indicator to both containers
    if (mobileChatMessages) {
      mobileChatMessages.insertAdjacentHTML('beforeend', loadingHTML)
      mobileChatMessages.scrollTop = mobileChatMessages.scrollHeight
    }
    
    if (desktopChatMessages) {
      desktopChatMessages.insertAdjacentHTML('beforeend', loadingHTML)
      desktopChatMessages.scrollTop = desktopChatMessages.scrollHeight
    }
    
    // Add CSS for the typing indicator if it doesn't exist
    if (!document.getElementById('typing-indicator-style')) {
      const style = document.createElement('style')
      style.id = 'typing-indicator-style'
      style.textContent = `
        .typing-indicator {
          display: flex;
          align-items: center;
        }
        .typing-indicator .dot {
          display: inline-block;
          width: 8px;
          height: 8px;
          border-radius: 50%;
          margin-right: 4px;
          background-color: var(--text-muted);
          animation: typing 1.5s infinite ease-in-out;
        }
        .typing-indicator .dot:nth-child(2) {
          animation-delay: 0.2s;
        }
        .typing-indicator .dot:nth-child(3) {
          animation-delay: 0.4s;
          margin-right: 0;
        }
        @keyframes typing {
          0%, 60%, 100% { transform: translateY(0); }
          30% { transform: translateY(-6px); }
        }
      `
      document.head.appendChild(style)
    }
  }
  
  // Remove loading indicator when AI response is received
  removeLoadingIndicator() {
    console.debug("[ChatFormController] Removing loading indicator")
    
    // Remove from both mobile and desktop containers
    const mobileLoadingIndicator = document.querySelector('#mobile_chat_messages #ai_loading_indicator')
    if (mobileLoadingIndicator) {
      mobileLoadingIndicator.remove()
    }
    
    const desktopLoadingIndicator = document.querySelector('#desktop_chat_messages #ai_loading_indicator')
    if (desktopLoadingIndicator) {
      desktopLoadingIndicator.remove()
    }
  }
  
  // Helper method to escape HTML to prevent XSS
  escapeHTML(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
