// app/javascript/controllers/chat_form_controller.js
//
// Stimulus controller for the chat form
// Handles immediate display of user messages and loading indicator

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["messageInput", "submitButton", "buttonText", "spinner"];
  
  connect() {
    console.debug("[ChatFormController] Connected");
    this.adjustHeight();
    this.messageInputTarget.focus();
  }
  
  disconnect() {
    console.debug("[ChatFormController] Disconnected");
  }
  
  // Auto-adjust the height of the text area as the user types
  adjustHeight() {
    const textarea = this.messageInputTarget;
    textarea.style.height = 'auto';
    const newHeight = Math.min(textarea.scrollHeight, 150);
    textarea.style.height = `${newHeight}px`;
  }
  
  // Handle keyboard events (Enter to send, Shift+Enter for new line)
  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      this.element.requestSubmit();
      console.debug("[ChatFormController] Form submitted via Enter key");
    }
  }
  
  // Handle form submission start - show loading state
  handleSubmitStart() {
    const message = this.messageInputTarget.value.trim();
    if (!message) return;
    
    console.debug("[ChatFormController] Submit start - adding message and loading indicator");
    
    // Add user message to chat
    this.addUserMessage(message);
    
    // Add loading indicator
    this.addLoadingIndicator();
    
    // Show loading state on button
    this.submitButtonTarget.disabled = true;
    this.buttonTextTarget.classList.add("opacity-0");
    this.spinnerTarget.classList.remove("d-none");
  }
  
  // Handle form submission end - reset form and loading state
  handleSubmitEnd() {
    console.debug("[ChatFormController] Submit end - removing loading indicator");
    
    // Remove loading indicator
    this.removeLoadingIndicator();
    
    // Reset form
    this.messageInputTarget.value = "";
    this.adjustHeight();
    this.messageInputTarget.focus();
    
    // Reset loading state
    this.submitButtonTarget.disabled = false;
    this.buttonTextTarget.classList.remove("opacity-0");
    this.spinnerTarget.classList.add("d-none");
  }
  
  // Add user message immediately to the chat
  addUserMessage(message) {
    console.debug("[ChatFormController] Adding user message to chat");
    
    const chatMessages = document.getElementById('chat_messages');
    if (!chatMessages) {
      console.error("[ChatFormController] Could not find chat messages container");
      return;
    }
    
    const messageId = `temp_user_message_${Date.now()}`;
    
    const messageHTML = `
      <div class="message mb-4 d-flex user-message justify-content-end temp-message" id="${messageId}">
        <div class="message-content p-3 rounded-3 shadow-sm text-white" style="max-width: 85%; background-color: var(--primary-color);">
          <div class="message-body">
            <p class="mb-1">${this.escapeHTML(message)}</p>
          </div>
          <div class="message-footer d-flex justify-content-between align-items-center mt-2">
            <small class="opacity-75">${new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}</small>
            <small class="opacity-75">You</small>
          </div>
        </div>
        <div class="message-avatar ms-3 flex-shrink-0">
          <div class="avatar bg-white text-primary border rounded-circle d-flex align-items-center justify-content-center" style="width: 38px; height: 38px;">
            <i class="bi bi-person"></i>
          </div>
        </div>
      </div>
    `;
    
    chatMessages.insertAdjacentHTML('beforeend', messageHTML);
    chatMessages.scrollTop = chatMessages.scrollHeight;
  }
  
  // Add loading indicator while waiting for AI response
  addLoadingIndicator() {
    console.debug("[ChatFormController] Adding loading indicator");
    
    const chatMessages = document.getElementById('chat_messages');
    if (!chatMessages) {
      console.error("[ChatFormController] Could not find chat messages container");
      return;
    }
    
    const loadingId = 'temp_ai_loading_indicator';
    
    // Remove any existing loading indicator
    const existingIndicator = document.getElementById(loadingId);
    if (existingIndicator) {
      existingIndicator.remove();
    }
    
    const loadingHTML = `
      <div class="message mb-4 d-flex ai-message temp-message" id="${loadingId}">
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
    `;
    
    chatMessages.insertAdjacentHTML('beforeend', loadingHTML);
    chatMessages.scrollTop = chatMessages.scrollHeight;
    
    // Add CSS for the typing indicator if it doesn't exist
    if (!document.getElementById('typing-indicator-style')) {
      const style = document.createElement('style');
      style.id = 'typing-indicator-style';
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
      `;
      document.head.appendChild(style);
    }
  }
  
  // Remove temporary messages when AI response is received
  removeLoadingIndicator() {
    console.debug("[ChatFormController] Removing temporary messages");
    
    document.querySelectorAll('.temp-message').forEach(el => {
      console.debug("[ChatFormController] Removing temporary message", el.id);
      el.remove();
    });
  }
  
  // Helper method to escape HTML to prevent XSS
  escapeHTML(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
}
