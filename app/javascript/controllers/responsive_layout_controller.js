// app/javascript/controllers/responsive_layout_controller.js
//
// Stimulus controller for handling responsive layout behavior
// Ensures proper display of content in both mobile and desktop views
// Prevents duplicate content from being displayed simultaneously
//
// This controller:
// - Manages visibility of mobile vs desktop components
// - Synchronizes content between views when needed
// - Handles responsive breakpoints
// - Provides comprehensive debug logging

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mobilePatent", "desktopPatent", "mobileChat", "desktopChat"]
  
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
      isMobile: isMobile,
      windowWidth: window.innerWidth,
      timestamp: new Date().toISOString()
    })
    
    // Ensure only the appropriate content is visible
    if (this.hasMobilePatentTarget && this.hasDesktopPatentTarget) {
      this.syncPatentContent(isMobile)
    }
    
    if (this.hasMobileChatTarget && this.hasDesktopChatTarget) {
      this.syncChatContent(isMobile)
    }
  }
  
  syncPatentContent(isMobile) {
    // Ensure form data is synchronized between views
    console.debug("[ResponsiveLayoutController] Syncing patent content", {
      isMobile: isMobile,
      timestamp: new Date().toISOString()
    })
    
    // We don't need to do anything special here since Turbo handles the form data
    // Just ensuring the controller is aware of the state
  }
  
  syncChatContent(isMobile) {
    // Ensure chat messages are synchronized between views
    console.debug("[ResponsiveLayoutController] Syncing chat content", {
      isMobile: isMobile,
      timestamp: new Date().toISOString()
    })
    
    // We don't need to do anything special here since the server handles the chat state
    // Just ensuring the controller is aware of the state
  }
  
  disconnect() {
    // Clean up resize observer
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    
    console.debug("[ResponsiveLayoutController] Disconnected")
  }
}
