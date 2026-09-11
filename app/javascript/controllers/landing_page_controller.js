import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "counter", "mobileMenu", "progressBar", "tabBtn", "tabPane", "dropdown" ]

  connect() {
    this.animateCounters()
    this.animateBars()
    this.boundHandleOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this.boundHandleOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleOutsideClick)
  }

  // --- Hero Tab Switching ---
  switchTab(event) {
    event.preventDefault()
    const targetTab = event.currentTarget.dataset.tab

    // Update tab button styles
    this.tabBtnTargets.forEach(btn => {
      const isSelected = btn.dataset.tab === targetTab
      if (isSelected) {
        btn.classList.add("bg-[#182938]", "text-white")
        btn.classList.remove("bg-white", "text-slate-700", "hover:bg-slate-50")
      } else {
        btn.classList.remove("bg-[#182938]", "text-white")
        btn.classList.add("bg-white", "text-slate-700", "hover:bg-slate-50")
      }
      btn.setAttribute("aria-selected", isSelected ? "true" : "false")
    })

    // Update tab panes
    this.tabPaneTargets.forEach(pane => {
      if (pane.dataset.tab === targetTab) {
        pane.classList.remove("hidden")
      } else {
        pane.classList.add("hidden")
      }
    })
  }

  // --- Navbar Dropdowns ---
  toggleDropdown(event) {
    event.stopPropagation()
    const clickedDropdown = event.currentTarget.closest("[data-landing-page-target='dropdown']")
    
    // Close other dropdowns
    this.dropdownTargets.forEach(d => {
      if (d !== clickedDropdown) {
        const menu = d.querySelector("[data-dropdown-menu]")
        const arrow = d.querySelector("[data-dropdown-arrow]")
        if (menu) menu.classList.add("hidden")
        if (arrow) arrow.classList.remove("rotate-180")
      }
    })

    if (clickedDropdown) {
      const menu = clickedDropdown.querySelector("[data-dropdown-menu]")
      const arrow = clickedDropdown.querySelector("[data-dropdown-arrow]")
      if (menu) {
        const isOpen = !menu.classList.contains("hidden")
        if (isOpen) {
          menu.classList.add("hidden")
          if (arrow) arrow.classList.remove("rotate-180")
        } else {
          menu.classList.remove("hidden")
          if (arrow) arrow.classList.add("rotate-180")
        }
      }
    }
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.closeAllDropdowns()
      return
    }

    // If click was not inside any dropdown target, close dropdowns
    let insideDropdown = false
    this.dropdownTargets.forEach(d => {
      if (d.contains(event.target)) insideDropdown = true
    })

    if (!insideDropdown) {
      this.closeAllDropdowns()
    }
  }

  closeAllDropdowns() {
    this.dropdownTargets.forEach(d => {
      const menu = d.querySelector("[data-dropdown-menu]")
      const arrow = d.querySelector("[data-dropdown-arrow]")
      if (menu) menu.classList.add("hidden")
      if (arrow) arrow.classList.remove("rotate-180")
    })
  }

  // --- Mobile Drawer ---
  toggleMobileMenu() {
    if (this.hasMobileMenuTarget) {
      this.mobileMenuTarget.classList.toggle("hidden")
      document.body.classList.toggle("overflow-hidden")
    }
  }

  closeMobileMenu() {
    if (this.hasMobileMenuTarget) {
      this.mobileMenuTarget.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
    }
  }

  // --- Dynamic Counter Animations ---
  animateCounters() {
    if (!("IntersectionObserver" in window)) {
      this.counterTargets.forEach(el => {
        el.textContent = el.dataset.count || el.textContent
      })
      return
    }

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const el = entry.target
          const target = parseInt(el.dataset.count, 10)
          if (isNaN(target)) return

          const duration = 1400
          const start = performance.now()

          const step = (timestamp) => {
            const progress = Math.min((timestamp - start) / duration, 1)
            const current = Math.floor((1 - (1 - progress) * (1 - progress)) * target)
            el.textContent = current.toLocaleString()
            if (progress < 1) {
              requestAnimationFrame(step)
            } else {
              el.textContent = target.toLocaleString()
            }
          }

          requestAnimationFrame(step)
          observer.unobserve(el)
        }
      })
    }, { threshold: 0.15 })

    this.counterTargets.forEach(el => observer.observe(el))
  }

  animateBars() {
    if (!("IntersectionObserver" in window)) {
      this.progressBarTargets.forEach(el => {
        el.style.width = el.dataset.width || "96%"
      })
      return
    }

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const el = entry.target
          el.style.width = el.dataset.width || "96%"
          observer.unobserve(el)
        }
      })
    }, { threshold: 0.2 })

    this.progressBarTargets.forEach(el => observer.observe(el))
  }
}

