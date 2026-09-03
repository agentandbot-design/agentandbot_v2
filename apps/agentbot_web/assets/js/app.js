// AgentAndBot — Phoenix LiveView app.js
// esbuild ile derlenir

import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

// CSRF token
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// ── Hooks ──────────────────────────────────────────────────────

// Yeni mesaj gelince alta kaydır (sadece kullanıcı zaten alttaysa)
const ChatScroll = {
  mounted() {
    this.el.addEventListener("aab:new-message", () => {
      const nearBottom =
        window.innerHeight + window.scrollY >= document.body.scrollHeight - 300
      if (nearBottom) {
        requestAnimationFrame(() =>
          window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" })
        )
      }
    })
    // İlk yüklemede en alta
    window.scrollTo({ top: document.body.scrollHeight })
  },
}

// İnsan adını localStorage'da hatırla
const RememberName = {
  mounted() {
    const saved = localStorage.getItem("aab:sender_name")
    if (saved && !this.el.value) {
      this.el.value = saved
      this.pushEvent("set_sender_name", { name: saved })
    }
    this.el.addEventListener("change", (e) => {
      if (e.target.value.trim()) {
        localStorage.setItem("aab:sender_name", e.target.value.trim())
      }
    })
  },
}

// Terminal gövdesini alta kaydır (yeni satır geldiğinde)

// SortableKanban — kanban sürükle-bırak hook
const SortableKanban = {
  mounted() { this._setupSortable() },
  updated() { this._setupSortable() },
  _setupSortable() {
    if (this._sortable || typeof Sortable === "undefined") return
    const el = document.getElementById("cards-" + this.el.dataset.roomId + "-" + this.el.dataset.stage)
    if (!el) return
    this._sortable = Sortable.create(el, {
      group: "kanban-" + this.el.dataset.roomId,
      animation: 150,
      ghostClass: "opacity-50",
      chosenClass: "ring-2 ring-blue-500",
      dragClass: "shadow-xl",
      handle: ".kanban-card",
      // Fallback pointer engine: required for touch/mobile (native HTML5 DnD
      // does not fire dragstart on touch devices), also works on desktop.
      forceFallback: true,
      fallbackOnBody: true,
      fallbackTolerance: 0,
      touchStartThreshold: 4,
      delay: 0,
      onEnd: (evt) => {
        const taskId = evt.item.dataset.taskId
        const stageEl = evt.to ? evt.to.closest("[data-stage]") : null
        const newStage = stageEl ? stageEl.dataset.stage : null
        if (taskId && newStage) {
          this.pushEvent("drop_task", { task_id: taskId, stage: newStage })
        }
      }
    })
  },
  destroyed() { if (this._sortable) { this._sortable.destroy(); this._sortable = null } }
}

const TermScroll = {
  mounted() {
    this.el.scrollTop = this.el.scrollHeight
  },
  updated() {
    this.el.scrollTop = this.el.scrollHeight
  },
}

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: { ChatScroll, RememberName, TermScroll, SortableKanban },
})

// Connect
liveSocket.connect()

// expose for debugging
window.liveSocket = liveSocket
