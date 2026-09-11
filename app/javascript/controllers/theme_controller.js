import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "icon", "text" ]

  connect() {
    this.applyTheme(this.currentTheme)
  }

  get currentTheme() {
    return "light"
  }

  toggle() {
    this.applyTheme("light")
  }

  applyTheme(theme) {
    document.documentElement.classList.remove("dark")
    document.documentElement.dataset.theme = "light"
    localStorage.setItem("theme", "light")
    this.updateIcons(false)
  }

  updateIcons(isDark) {
    if (this.hasIconTarget) {
      this.iconTarget.className = isDark ? "fas fa-moon text-accent" : "fas fa-sun text-accent"
    }
    if (this.hasTextTarget) {
      this.textTarget.textContent = isDark ? "Dark Theme" : "Light Theme"
    }
  }
}
