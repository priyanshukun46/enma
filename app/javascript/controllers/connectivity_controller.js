import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["banner", "demoButton"]

  connect() {
    this.simulatedOffline = false
    this.updateOnlineStatus()
    this.boundUpdate = this.updateOnlineStatus.bind(this)
    window.addEventListener("online", this.boundUpdate)
    window.addEventListener("offline", this.boundUpdate)
  }

  disconnect() {
    window.removeEventListener("online", this.boundUpdate)
    window.removeEventListener("offline", this.boundUpdate)
  }

  updateOnlineStatus() {
    const isOffline = !navigator.onLine || this.simulatedOffline

    if (isOffline) {
      this.bannerTarget.classList.remove("hidden")
    } else {
      this.bannerTarget.classList.add("hidden")
    }
    
    // Update the button UI if it exists
    if (this.hasDemoButtonTarget) {
      if (this.simulatedOffline) {
        this.demoButtonTarget.classList.add("bg-rose-600", "text-white", "border-rose-700")
        this.demoButtonTarget.classList.remove("bg-paper", "text-mute", "border-[var(--line)]")
        this.demoButtonTarget.innerHTML = `<i class="fas fa-wifi-slash mr-1"></i> Simulated Offline`
      } else {
        this.demoButtonTarget.classList.remove("bg-rose-600", "text-white", "border-rose-700")
        this.demoButtonTarget.classList.add("bg-paper", "text-mute", "border-[var(--line)]")
        this.demoButtonTarget.innerHTML = `<i class="fas fa-flask mr-1"></i> Simulate Offline`
      }
    }
  }

  toggleSimulatedOffline() {
    this.simulatedOffline = !this.simulatedOffline
    
    if (navigator.serviceWorker && navigator.serviceWorker.controller) {
      navigator.serviceWorker.controller.postMessage({
        type: "SIMULATE_OFFLINE_TOGGLE",
        value: this.simulatedOffline
      })
    }
    
    this.updateOnlineStatus()
  }
}
