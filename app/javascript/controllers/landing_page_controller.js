import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "counter", "mobileMenu", "progressBar" ]

  connect() {
    this.animateCounters()
    this.animateBars()
  }

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
            // Ease out quad
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
