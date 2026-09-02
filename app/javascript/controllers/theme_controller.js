import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "icon", "text" ]

  connect() {
    this.applyTheme(this.currentTheme)
  }

  get currentTheme() {
    const saved = localStorage.getItem("theme")
    if (saved) return saved
    return window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark"
  }

  toggle() {
    const isDark = document.documentElement.classList.contains("dark") || document.documentElement.dataset.theme === "dark"
    const newTheme = isDark ? "light" : "dark"
    this.applyTheme(newTheme)
  }

  applyTheme(theme) {
    const isDark = theme === "dark"
    if (isDark) {
      document.documentElement.classList.add("dark")
      document.documentElement.dataset.theme = "dark"
      localStorage.setItem("theme", "dark")
      this.updateIcons(true)
    } else {
      document.documentElement.classList.remove("dark")
      document.documentElement.dataset.theme = "light"
      localStorage.setItem("theme", "light")
      this.updateIcons(false)
    }
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
