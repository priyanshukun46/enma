import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "modal", "backdrop", "input", "resultsList" ]
  static values = {
    selectedIndex: { type: Number, default: -1 }
  }

  connect() {
    this.boundGlobalKeydown = this.handleGlobalKeydown.bind(this)
    window.addEventListener("keydown", this.boundGlobalKeydown)
    this.debounceTimer = null
    this.items = []
  }

  disconnect() {
    window.removeEventListener("keydown", this.boundGlobalKeydown)
    clearTimeout(this.debounceTimer)
  }

  handleGlobalKeydown(event) {
    // Open on Cmd+K or Ctrl+K
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      event.preventDefault()
      this.open()
    } else if (event.key === "Escape" && this.isOpen()) {
      event.preventDefault()
      this.close()
    }
  }

  isOpen() {
    return this.hasModalTarget && !this.modalTarget.classList.contains("hidden")
  }

  open(event) {
    if (event) event.preventDefault()

    if (this.hasModalTarget) this.modalTarget.classList.remove("hidden")
    if (this.hasBackdropTarget) this.backdropTarget.classList.remove("hidden")

    setTimeout(() => {
      if (this.hasInputTarget) {
        this.inputTarget.focus()
        this.inputTarget.select()
        this.fetchSuggestions(this.inputTarget.value.trim())
      }
    }, 50)
  }

  close() {
    if (this.hasModalTarget) this.modalTarget.classList.add("hidden")
    if (this.hasBackdropTarget) this.backdropTarget.classList.add("hidden")
    this.selectedIndexValue = -1
  }

  onInput() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      const query = this.inputTarget.value.trim()
      this.fetchSuggestions(query)
    }, 150)
  }

  setQuery(event) {
    const query = event.currentTarget.dataset.query
    if (query && this.hasInputTarget) {
      this.inputTarget.value = query
      this.fetchSuggestions(query)
    }
  }

  async fetchSuggestions(query) {
    try {
      const response = await fetch(`/search/suggestions?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return
      const data = await response.json()
      this.items = data.suggestions || []
      this.selectedIndexValue = -1
      this.renderSuggestions(this.items, query)
    } catch (err) {
      console.error("Search modal fetch failed:", err)
    }
  }

  renderSuggestions(items, query) {
    if (!this.hasResultsListTarget) return

    if (items.length === 0) {
      this.resultsListTarget.innerHTML = `
        <div class="px-6 py-8 text-center space-y-2">
          <div class="w-10 h-10 rounded-full bg-surface sketch-border-soft text-mute flex items-center justify-center text-sm mx-auto">
            <i class="fas fa-search"></i>
          </div>
          <p class="text-xs text-mute font-medium">No quick matches found for "<span class="text-ink font-bold">${this.escapeHtml(query)}</span>"</p>
          <a href="/search?q=${encodeURIComponent(query)}" class="inline-block text-xs font-bold text-accent hover:underline pt-1">
            Run full database search &rarr;
          </a>
        </div>
      `
      return
    }

    const html = items.map((item, index) => {
      const categoryColor = this.getCategoryBadge(item.category)
      return `
        <li data-index="${index}"
            data-action="click->search-modal#selectItem mouseenter->search-modal#highlightItem"
            class="px-4 py-3 rounded-xl hover:bg-ink/5 dark:hover:bg-white/5 cursor-pointer flex items-center justify-between transition-colors group">
          <div class="flex items-center space-x-3.5 min-w-0 flex-1">
            <div class="w-8 h-8 rounded-lg bg-surface sketch-border-soft flex items-center justify-center text-accent text-sm flex-shrink-0 group-hover:scale-105 transition-transform">
              <i class="fas ${item.icon || 'fa-search'}"></i>
            </div>
            <div class="min-w-0 flex-1">
              <div class="text-xs sm:text-sm font-bold text-ink truncate">${this.highlightMatch(item.title, query)}</div>
              ${item.subtitle ? `<div class="text-[11px] text-mute truncate mt-0.5">${item.subtitle}</div>` : ''}
            </div>
          </div>
          <div class="flex items-center space-x-2.5 ml-3 flex-shrink-0">
            <span class="px-2 py-0.5 rounded text-[9px] font-black uppercase ${categoryColor}">
              ${item.badge || item.category}
            </span>
            <i class="fas fa-arrow-right text-xs text-mute group-hover:text-accent group-hover:translate-x-1 transition-all"></i>
          </div>
        </li>
      `
    }).join("")

    this.resultsListTarget.innerHTML = html
  }

  getCategoryBadge(category) {
    switch (category) {
      case "Location":
        return "bg-blue-500/10 text-blue-600 dark:text-blue-400 border border-blue-500/20"
      case "Road":
        return "bg-accent/10 text-accent border border-accent/20"
      case "Warehouse":
        return "bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20"
      case "Emergency":
        return "bg-red-500/10 text-red-600 dark:text-red-400 border border-red-500/20"
      default:
        return "bg-ink/5 text-ink border border-ink/15"
    }
  }

  highlightMatch(text, query) {
    if (!query) return this.escapeHtml(text)
    const escaped = this.escapeHtml(text)
    const regex = new RegExp(`(${query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi')
    return escaped.replace(regex, '<span class="text-accent underline font-black">$1</span>')
  }

  onKeydown(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.moveSelection(1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.moveSelection(-1)
        break
      case "Enter":
        event.preventDefault()
        if (this.selectedIndexValue >= 0 && this.selectedIndexValue < this.items.length) {
          this.navigateToItem(this.items[this.selectedIndexValue])
        } else if (this.inputTarget.value.trim().length > 0) {
          window.location.href = `/search?q=${encodeURIComponent(this.inputTarget.value.trim())}`
        }
        break
      case "Escape":
        this.close()
        break
    }
  }

  moveSelection(delta) {
    const listItems = this.resultsListTarget.querySelectorAll("li[data-index]")
    if (listItems.length === 0) return

    this.selectedIndexValue = Math.max(-1, Math.min(listItems.length - 1, this.selectedIndexValue + delta))

    listItems.forEach((li, idx) => {
      if (idx === this.selectedIndexValue) {
        li.classList.add("bg-ink/10", "dark:bg-white/10")
        li.scrollIntoView({ block: "nearest" })
      } else {
        li.classList.remove("bg-ink/10", "dark:bg-white/10")
      }
    })
  }

  highlightItem(event) {
    const li = event.currentTarget
    const index = parseInt(li.dataset.index, 10)
    if (!isNaN(index)) {
      this.selectedIndexValue = index
      const listItems = this.resultsListTarget.querySelectorAll("li[data-index]")
      listItems.forEach((item, idx) => {
        if (idx === index) {
          item.classList.add("bg-ink/10", "dark:bg-white/10")
        } else {
          item.classList.remove("bg-ink/10", "dark:bg-white/10")
        }
      })
    }
  }

  selectItem(event) {
    const li = event.currentTarget
    const index = parseInt(li.dataset.index, 10)
    if (!isNaN(index) && this.items[index]) {
      this.navigateToItem(this.items[index])
    }
  }

  navigateToItem(item) {
    if (item && item.url) {
      this.close()
      window.location.href = item.url
    }
  }

  escapeHtml(str) {
    return str ? String(str).replace(/[&<>"']/g, m => ({
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;'
    })[m]) : ''
  }
}
