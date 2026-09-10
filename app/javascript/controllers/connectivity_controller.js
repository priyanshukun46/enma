import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["banner"]

  connect() {
    this.updateOnlineStatus()
    window.addEventListener("online", this.updateOnlineStatus.bind(this))
    window.addEventListener("offline", this.updateOnlineStatus.bind(this))
  }

  disconnect() {
    window.removeEventListener("online", this.updateOnlineStatus.bind(this))
    window.removeEventListener("offline", this.updateOnlineStatus.bind(this))
  }

  updateOnlineStatus() {
    if (navigator.onLine) {
      this.bannerTarget.classList.add("hidden")
    } else {
      this.bannerTarget.classList.remove("hidden")
    }
  }
}
