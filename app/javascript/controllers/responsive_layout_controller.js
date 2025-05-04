// app/javascript/controllers/responsive_layout_controller.js
//
// Stimulus controller for handling responsive layout behavior
// Ensures proper display of content across all device sizes
// Handles layout adjustments based on screen size
//
// This controller:
// - Manages responsive layout changes
// - Handles responsive breakpoints
// - Provides comprehensive debug logging

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["patentForm", "chatContainer"]
  
  connect() {
    console.debug("[ResponsiveLayoutController] Connected")
    
    // Set up resize observer to handle screen size changes
    this.setupResponsiveHandling()
    
    // Initial check
    this.handleResponsiveDisplay()
  }
  
  setupResponsiveHandling() {
    // Handle resize events
    this.resizeObserver = new ResizeObserver(entries => {
      this.handleResponsiveDisplay()
    })
    
    // Observe the document body for size changes
    this.resizeObserver.observe(document.body)
    
    console.debug("[ResponsiveLayoutController] Resize observer setup")
  }
  
  handleResponsiveDisplay() {
    const isMobile = window.innerWidth < 768 // Bootstrap md breakpoint
    
    console.debug("[ResponsiveLayoutController] Handling responsive display", {
      screenWidth: window.innerWidth,
      isMobileView: isMobile,
      timestamp: new Date().toISOString()
    })
    
    // Apply any responsive adjustments if needed
    if (this.hasPatentFormTarget) {
      this.adjustPatentForm(isMobile)
    }
    
    if (this.hasChatContainerTarget) {
      this.adjustChatContainer(isMobile)
    }
  }
  
  adjustPatentForm(isMobile) {
    // Apply any responsive adjustments to the patent form
    console.debug("[ResponsiveLayoutController] Adjusting patent form layout", {
      isMobileView: isMobile,
      timestamp: new Date().toISOString()
    })
    
    // No specific adjustments needed as CSS handles most of the responsive behavior
    // This method exists for potential future enhancements
  }
  
  adjustChatContainer(isMobile) {
    // Apply any responsive adjustments to the chat container
    console.debug("[ResponsiveLayoutController] Adjusting chat container layout", {
      isMobileView: isMobile,
      timestamp: new Date().toISOString()
    })
    
    // Ensure chat messages container scrolls to bottom when layout changes
    const chatMessages = document.getElementById('chat_messages')
    if (chatMessages) {
      chatMessages.scrollTop = chatMessages.scrollHeight
    }
  }
  
  disconnect() {
    // Clean up resize observer
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    
    console.debug("[ResponsiveLayoutController] Disconnected")
  }
}
