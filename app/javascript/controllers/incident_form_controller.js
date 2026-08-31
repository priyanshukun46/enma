import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "latitude",
    "longitude",
    "locationName",
    "gpsLoadingState",
    "gpsSuccessState",
    "gpsFailedState",
    "latitudeDisplay",
    "longitudeDisplay",
    "accuracyDisplay",
    "manualCoordinatesPanel",
    "fileInput",
    "cameraInput",
    "previewContainer",
    "emptyPreviewNotice",
    "photoCountBadge",
    "descriptionInput",
    "descriptionCount",
    "criticalAlertBanner",
    "submitButton",
    "submitSpinner",
    "submitLabel",
    // Live Summary Targets
    "summaryTypeEmoji",
    "summaryTypeLabel",
    "summarySeverityBadge",
    "summarySeverityLabel",
    "summaryLocationText",
    "summaryPhotosText"
  ]

  connect() {
    this.selectedFiles = []
    this.updateDescriptionCount()
    this.updateLiveSummary()

    // Auto-attempt geolocation on load if coordinates are blank
    if (this.hasLatitudeTarget && !this.latitudeTarget.value) {
      this.captureLocation(false)
    } else if (this.hasLatitudeTarget && this.latitudeTarget.value) {
      this.showGpsSuccess(this.latitudeTarget.value, this.longitudeTarget.value, 15)
    }
  }

  // =========================================================================
  // 1. Incident Type Selection & Live Summary Sync
  // =========================================================================
  selectType(event) {
    const radio = event.currentTarget.querySelector('input[type="radio"]')
    if (radio) {
      radio.checked = true
    }

    const emoji = event.currentTarget.dataset.typeEmoji || "🪨"
    const label = event.currentTarget.dataset.typeLabel || "Landslide"

    if (this.hasSummaryTypeEmojiTarget) this.summaryTypeEmojiTarget.textContent = emoji
    if (this.hasSummaryTypeLabelTarget) this.summaryTypeLabelTarget.textContent = label

    this.updateLiveSummary()
  }

  // =========================================================================
  // 2. Severity Selection & Contextual Alert
  // =========================================================================
  selectSeverity(event) {
    const val = event.currentTarget.dataset.severityValue || "medium"
    const label = event.currentTarget.dataset.severityLabel || "Medium"
    const badgeClass = event.currentTarget.dataset.badgeClass || ""

    // Contextual alert when Critical is selected
    if (this.hasCriticalAlertBannerTarget) {
      if (val === "critical") {
        this.criticalAlertBannerTarget.classList.remove("hidden")
      } else {
        this.criticalAlertBannerTarget.classList.add("hidden")
      }
    }

    if (this.hasSummarySeverityLabelTarget) {
      this.summarySeverityLabelTarget.textContent = label
    }

    if (this.hasSummarySeverityBadgeTarget) {
      this.summarySeverityBadgeTarget.className = `px-2 py-0.5 rounded-full text-[10px] font-black uppercase border ${badgeClass}`
      this.summarySeverityBadgeTarget.textContent = label
    }

    this.updateLiveSummary()
  }

  // =========================================================================
  // 3. Browser Geolocation API & Hotwire Native Hooks
  // =========================================================================
  captureLocation(showFeedback = true) {
    this.showGpsLoading()

    // 1. Hotwire Native / Bridge Check (Future Native App hook)
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.nativeLocation) {
      window.webkit.messageHandlers.nativeLocation.postMessage({ action: "getLocation" })
      return
    }

    if (!navigator.geolocation) {
      this.showGpsFailed("Geolocation is not supported by your browser.")
      return
    }

    const options = {
      enableHighAccuracy: true,
      timeout: 10000,
      maximumAge: 0
    }

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const lat = pos.coords.latitude.toFixed(6)
        const lon = pos.coords.longitude.toFixed(6)
        const accuracy = Math.round(pos.coords.accuracy)

        if (this.hasLatitudeTarget) this.latitudeTarget.value = lat
        if (this.hasLongitudeTarget) this.longitudeTarget.value = lon

        this.showGpsSuccess(lat, lon, accuracy)
        this.updateLiveSummary()
      },
      (err) => {
        let msg = "Could not obtain GPS coordinates."
        if (err.code === err.PERMISSION_DENIED) {
          msg = "GPS permission denied. Please allow location access or enter coordinates manually."
        } else if (err.code === err.TIMEOUT) {
          msg = "GPS signal acquisition timed out. Please try again or enter coordinates manually."
        }
        this.showGpsFailed(msg)
        this.updateLiveSummary()
      },
      options
    )
  }

  showGpsLoading() {
    if (this.hasGpsLoadingStateTarget) this.gpsLoadingStateTarget.classList.remove("hidden")
    if (this.hasGpsSuccessStateTarget) this.gpsSuccessStateTarget.classList.add("hidden")
    if (this.hasGpsFailedStateTarget) this.gpsFailedStateTarget.classList.add("hidden")
  }

  showGpsSuccess(lat, lon, accuracy) {
    if (this.hasGpsLoadingStateTarget) this.gpsLoadingStateTarget.classList.add("hidden")
    if (this.hasGpsFailedStateTarget) this.gpsFailedStateTarget.classList.add("hidden")
    if (this.hasGpsSuccessStateTarget) this.gpsSuccessStateTarget.classList.remove("hidden")

    if (this.hasLatitudeDisplayTarget) this.latitudeDisplayTarget.textContent = `${lat}°N`
    if (this.hasLongitudeDisplayTarget) this.longitudeDisplayTarget.textContent = `${lon}°E`
    if (this.hasAccuracyDisplayTarget) this.accuracyDisplayTarget.textContent = `±${accuracy}m accuracy`
  }

  showGpsFailed(msg) {
    if (this.hasGpsLoadingStateTarget) this.gpsLoadingStateTarget.classList.add("hidden")
    if (this.hasGpsSuccessStateTarget) this.gpsSuccessStateTarget.classList.add("hidden")
    if (this.hasGpsFailedStateTarget) {
      this.gpsFailedStateTarget.classList.remove("hidden")
      const desc = this.gpsFailedStateTarget.querySelector("[data-gps-error-msg]")
      if (desc) desc.textContent = msg
    }
  }

  toggleManualCoordinates() {
    if (this.hasManualCoordinatesPanelTarget) {
      this.manualCoordinatesPanelTarget.classList.toggle("hidden")
    }
  }

  // =========================================================================
  // 4. Photo Evidence, Mobile Camera Capture & Previews
  // =========================================================================
  handleFiles(event) {
    const files = Array.from(event.target.files)
    if (!files || files.length === 0) return

    const remainingSlots = 5 - this.selectedFiles.length
    if (remainingSlots <= 0) {
      alert("Maximum 5 photos allowed per incident report.")
      return
    }

    const newFiles = files.slice(0, remainingSlots)
    this.selectedFiles = this.selectedFiles.concat(newFiles)
    this.syncFileInput()
    this.renderPreviews()
    this.updateLiveSummary()
  }

  removeFile(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    if (index >= 0 && index < this.selectedFiles.length) {
      this.selectedFiles.splice(index, 1)
      this.syncFileInput()
      this.renderPreviews()
      this.updateLiveSummary()
    }
  }

  syncFileInput() {
    if (!this.hasFileInputTarget) return

    const dataTransfer = new DataTransfer()
    this.selectedFiles.forEach((file) => dataTransfer.items.add(file))
    this.fileInputTarget.files = dataTransfer.files
  }

  renderPreviews() {
    if (!this.hasPreviewContainerTarget) return

    const count = this.selectedFiles.length

    if (this.hasPhotoCountBadgeTarget) {
      if (count > 0) {
        this.photoCountBadgeTarget.textContent = `${count} of 5 photos attached`
        this.photoCountBadgeTarget.classList.remove("hidden")
      } else {
        this.photoCountBadgeTarget.classList.add("hidden")
      }
    }

    if (count === 0) {
      this.previewContainerTarget.innerHTML = ""
      if (this.hasEmptyPreviewNoticeTarget) {
        this.emptyPreviewNoticeTarget.classList.remove("hidden")
      }
      return
    }

    if (this.hasEmptyPreviewNoticeTarget) {
      this.emptyPreviewNoticeTarget.classList.add("hidden")
    }

    this.previewContainerTarget.innerHTML = ""

    this.selectedFiles.forEach((file, idx) => {
      const card = document.createElement("div")
      card.className = "relative group rounded-2xl overflow-hidden border-2 border-slate-200 dark:border-slate-700 bg-slate-100 dark:bg-slate-800 aspect-square shadow-sm animate-fadeIn"

      const img = document.createElement("img")
      img.className = "w-full h-full object-cover"
      img.src = URL.createObjectURL(file)

      const removeBtn = document.createElement("button")
      removeBtn.type = "button"
      removeBtn.dataset.action = "click->incident-form#removeFile"
      removeBtn.dataset.index = idx
      removeBtn.className = "absolute top-2 right-2 w-7 h-7 rounded-full bg-red-600 hover:bg-red-700 text-white flex items-center justify-center text-xs shadow-lg transition-all cursor-pointer z-10"
      removeBtn.innerHTML = '<i class="fas fa-times"></i>'
      removeBtn.title = "Remove photo"

      const badge = document.createElement("div")
      badge.className = "absolute bottom-1.5 left-1.5 px-2 py-0.5 rounded-md bg-black/75 text-white text-[10px] font-mono truncate max-w-[85%]"
      badge.textContent = `${(file.size / 1024 / 1024).toFixed(1)} MB`

      card.appendChild(img)
      card.appendChild(removeBtn)
      card.appendChild(badge)
      this.previewContainerTarget.appendChild(card)
    })

    // If slots available, append an "Add More" tile
    if (count < 5) {
      const addTile = document.createElement("button")
      addTile.type = "button"
      addTile.onclick = () => {
        if (this.hasFileInputTarget) this.fileInputTarget.click()
      }
      addTile.className = "rounded-2xl border-2 border-dashed border-slate-300 dark:border-slate-700 hover:border-indigo-500 bg-slate-50/50 dark:bg-slate-800/40 aspect-square flex flex-col items-center justify-center text-slate-400 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors cursor-pointer"
      addTile.innerHTML = `
        <i class="fas fa-plus text-lg mb-1"></i>
        <span class="text-[10px] font-black uppercase tracking-wider">Add More</span>
      `
      this.previewContainerTarget.appendChild(addTile)
    }
  }

  // =========================================================================
  // 5. Description & Live Summary
  // =========================================================================
  updateDescriptionCount() {
    if (!this.hasDescriptionInputTarget || !this.hasDescriptionCountTarget) return
    const len = this.descriptionInputTarget.value.length
    this.descriptionCountTarget.textContent = `${len} / 2000 chars`
  }

  updateLiveSummary() {
    // Summary Location
    if (this.hasSummaryLocationTextTarget) {
      const lat = this.hasLatitudeTarget && this.latitudeTarget.value ? parseFloat(this.latitudeTarget.value).toFixed(4) : null
      const lon = this.hasLongitudeTarget && this.longitudeTarget.value ? parseFloat(this.longitudeTarget.value).toFixed(4) : null

      if (lat && lon) {
        this.summaryLocationTextTarget.textContent = `📍 ${lat}°N, ${lon}°E`
      } else {
        this.summaryLocationTextTarget.textContent = "📍 Location pending GPS fix"
      }
    }

    // Summary Photos
    if (this.hasSummaryPhotosTextTarget) {
      const count = this.selectedFiles.length
      this.summaryPhotosTextTarget.textContent = count > 0 ? `📷 ${count} photo(s) attached` : "📷 No photos attached"
    }
  }

  // =========================================================================
  // 6. Form Submission & Duplicate Click Guard
  // =========================================================================
  submitForm(event) {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("opacity-75", "cursor-not-allowed")
    }

    if (this.hasSubmitSpinnerTarget) {
      this.submitSpinnerTarget.classList.remove("hidden")
    }

    if (this.hasSubmitLabelTarget) {
      this.submitLabelTarget.textContent = "Submitting Incident Report..."
    }
  }
}
