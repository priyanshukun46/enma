import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "sidebar", "backdrop" ]

  toggle() {
    if (this.hasSidebarTarget) {
      this.sidebarTarget.classList.toggle("-translate-x-full")
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.toggle("hidden")
    }
  }

  close() {
    if (this.hasSidebarTarget) {
      this.sidebarTarget.classList.add("-translate-x-full")
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.add("hidden")
    }
  }
}
