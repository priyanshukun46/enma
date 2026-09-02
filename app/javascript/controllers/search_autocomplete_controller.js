import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "dropdown", "resultsList" ]
  static values = {
    url: { type: String, default: "/search/suggestions" },
    selectedIndex: { type: Number, default: -1 }
  }

  connect() {
    this.debounceTimer = null
    this.items = []
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
  }

  onFocus() {
    const query = this.inputTarget.value.trim()
    this.fetchSuggestions(query)
  }

  onInput() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      const query = this.inputTarget.value.trim()
      this.fetchSuggestions(query)
    }, 150)
  }

  async fetchSuggestions(query) {
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return
      const data = await response.json()
      this.items = data.suggestions || []
      this.selectedIndexValue = -1
      this.renderSuggestions(this.items, query)
    } catch (err) {
      console.error("Search suggestion fetch failed:", err)
    }
  }

  renderSuggestions(items, query) {
    if (!this.hasDropdownTarget || !this.hasResultsListTarget) return

    if (items.length === 0) {
      if (query.length > 0) {
        this.resultsListTarget.innerHTML = `
          <div class="px-4 py-3 text-center text-xs text-mute font-medium">
            No quick matches found for "<span class="text-ink font-bold">${this.escapeHtml(query)}</span>".<br>
            <span class="text-[11px] text-accent">Press Enter to search all database records &rarr;</span>
          </div>
        `
        this.showDropdown()
      } else {
        this.hideDropdown()
      }
      return
    }

    const html = items.map((item, index) => {
      const categoryColor = this.getCategoryBadge(item.category)
      return `
        <li data-index="${index}"
            data-action="click->search-autocomplete#selectItem mouseenter->search-autocomplete#highlightItem"
            class="px-3.5 py-2.5 rounded-xl hover:bg-ink/5 dark:hover:bg-white/5 cursor-pointer flex items-center justify-between transition-colors group">
          <div class="flex items-center space-x-3 min-w-0 flex-1">
            <div class="w-7 h-7 rounded-lg bg-surface sketch-border-soft flex items-center justify-center text-accent text-xs flex-shrink-0 group-hover:scale-105 transition-transform">
              <i class="fas ${item.icon || 'fa-search'}"></i>
            </div>
            <div class="min-w-0 flex-1">
              <div class="text-xs font-bold text-ink truncate">${this.highlightMatch(item.title, query)}</div>
              ${item.subtitle ? `<div class="text-[10px] text-mute truncate">${item.subtitle}</div>` : ''}
            </div>
          </div>
          <div class="flex items-center space-x-2 ml-2 flex-shrink-0">
            <span class="px-2 py-0.5 rounded text-[9px] font-black uppercase ${categoryColor}">
              ${item.badge || item.category}
            </span>
            <i class="fas fa-arrow-right text-[10px] text-mute group-hover:text-accent group-hover:translate-x-0.5 transition-all"></i>
          </div>
        </li>
      `
    }).join("")

    const footer = `
      <div class="px-3.5 py-2 border-t border-[var(--line)] flex items-center justify-between text-[10px] text-mute bg-surface/50 rounded-b-xl">
        <span><kbd class="px-1 py-0.5 rounded bg-ink/5 border border-ink/15 font-mono">↑↓</kbd> navigate &bull; <kbd class="px-1 py-0.5 rounded bg-ink/5 border border-ink/15 font-mono">Enter</kbd> open</span>
        <a href="/search?q=${encodeURIComponent(query)}" class="text-accent font-bold hover:underline">Full Search &rarr;</a>
      </div>
    `

    this.resultsListTarget.innerHTML = html + footer
    this.showDropdown()
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
    if (!this.dropdownOpen) return

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
        if (this.selectedIndexValue >= 0 && this.selectedIndexValue < this.items.length) {
          event.preventDefault()
          this.navigateToItem(this.items[this.selectedIndexValue])
        }
        break
      case "Escape":
        this.hideDropdown()
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
      this.hideDropdown()
      window.location.href = item.url
    }
  }

  onClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideDropdown()
    }
  }

  showDropdown() {
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.remove("hidden")
      this.dropdownOpen = true
    }
  }

  hideDropdown() {
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.add("hidden")
      this.dropdownOpen = false
      this.selectedIndexValue = -1
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
