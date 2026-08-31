import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "modalImage", "modalCaption"]

  open(event) {
    const src = event.currentTarget.dataset.fullSrc || event.currentTarget.src
    const caption = event.currentTarget.dataset.caption || "Incident Evidence Photo"

    if (this.hasModalImageTarget && src) {
      this.modalImageTarget.src = src
    }

    if (this.hasModalCaptionTarget) {
      this.modalCaptionTarget.textContent = caption
    }

    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
      document.body.classList.add("overflow-hidden")
    }
  }

  close() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
    }
  }
}
