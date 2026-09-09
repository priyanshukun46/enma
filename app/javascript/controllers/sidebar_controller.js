import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "sidebar", "backdrop" ]

  connect() {
    this.restoreCategoryState()
  }

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

  toggleCategory(event) {
    const details = event.currentTarget.closest("details")
    if (!details) return
    const key = details.dataset.categoryKey
    if (!key) return

    // The open attribute updates immediately after the click event
    setTimeout(() => {
      try {
        const state = JSON.parse(localStorage.getItem("resqway_sidebar_categories") || localStorage.getItem("enma_sidebar_categories") || "{}")
        state[key] = details.open
        localStorage.setItem("resqway_sidebar_categories", JSON.stringify(state))
      } catch (e) {}
    }, 20)
  }

  restoreCategoryState() {
    try {
      const state = JSON.parse(localStorage.getItem("resqway_sidebar_categories") || localStorage.getItem("enma_sidebar_categories") || "{}")
      this.element.querySelectorAll("details[data-category-key]").forEach((el) => {
        const key = el.dataset.categoryKey
        // If this section contains the current active route link, keep it open
        const hasActiveLink = el.querySelector("a.bg-ink") !== null
        if (hasActiveLink) {
          el.open = true
        } else if (state[key] !== undefined) {
          el.open = state[key]
        }
      })
    } catch (e) {}
  }
}
