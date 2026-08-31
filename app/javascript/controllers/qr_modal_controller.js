import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "modal", "backdrop", "copyButton", "copyText", "urlText" ]

  open() {
    if (this.hasModalTarget) this.modalTarget.classList.remove("hidden")
    if (this.hasBackdropTarget) this.backdropTarget.classList.remove("hidden")
  }

  close() {
    if (this.hasModalTarget) this.modalTarget.classList.add("hidden")
    if (this.hasBackdropTarget) this.backdropTarget.classList.add("hidden")
  }

  async copyLink(event) {
    event?.preventDefault()
    const url = this.hasUrlTextTarget ? this.urlTextTarget.textContent.trim() : window.location.origin

    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(url)
      } else {
        const textarea = document.createElement("textarea")
        textarea.value = url
        document.body.appendChild(textarea)
        textarea.select()
        document.execCommand("copy")
        document.body.removeChild(textarea)
      }

      if (this.hasCopyTextTarget) {
        const original = this.copyTextTarget.textContent
        this.copyTextTarget.textContent = "Copied!"
        if (this.hasCopyButtonTarget) {
          this.copyButtonTarget.classList.add("bg-emerald-600", "text-white")
        }
        setTimeout(() => {
          this.copyTextTarget.textContent = original
          if (this.hasCopyButtonTarget) {
            this.copyButtonTarget.classList.remove("bg-emerald-600", "text-white")
          }
        }, 2000)
      }
    } catch (err) {
      console.warn("Failed to copy URL:", err)
    }
  }
}
