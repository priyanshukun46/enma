import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    timeout: { type: Number, default: 2000 }
  }

  connect() {
    this.element.style.transition = "all 0.35s cubic-bezier(0.16, 1, 0.3, 1)"
    this.startTimer()
  }

  disconnect() {
    this.clearTimer()
  }

  startTimer() {
    if (this.timeoutValue > 0) {
      this.timer = setTimeout(() => {
        this.dismiss()
      }, this.timeoutValue)
    }
  }

  clearTimer() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  pause() {
    this.clearTimer()
  }

  resume() {
    this.clearTimer()
    this.startTimer()
  }

  dismiss(event) {
    if (event) event.preventDefault()
    this.clearTimer()

    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-6px)"
    this.element.style.maxHeight = `${this.element.scrollHeight}px`

    requestAnimationFrame(() => {
      this.element.style.maxHeight = "0px"
      this.element.style.paddingTop = "0px"
      this.element.style.paddingBottom = "0px"
      this.element.style.marginTop = "0px"
      this.element.style.marginBottom = "0px"
      this.element.style.overflow = "hidden"
    })

    setTimeout(() => {
      this.element.remove()
    }, 360)
  }
}
