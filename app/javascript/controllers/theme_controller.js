import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "icon", "text" ]

  connect() {
    this.applyTheme(this.currentTheme)
  }

  get currentTheme() {
    return localStorage.getItem("theme") || (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
  }

  toggle() {
    const newTheme = document.documentElement.classList.contains("dark") ? "light" : "dark"
    this.applyTheme(newTheme)
  }

  applyTheme(theme) {
    if (theme === "dark") {
      document.documentElement.classList.add("dark")
      localStorage.setItem("theme", "dark")
      this.updateIcons(true)
    } else {
      document.documentElement.classList.remove("dark")
      localStorage.setItem("theme", "light")
      this.updateIcons(false)
    }
  }

  updateIcons(isDark) {
    if (this.hasIconTarget) {
      this.iconTarget.className = isDark ? "fas fa-sun text-amber-400" : "fas fa-moon text-slate-600 dark:text-slate-300"
    }
    if (this.hasTextTarget) {
      this.textTarget.textContent = isDark ? "Light Mode" : "Dark Mode"
    }
  }
}
