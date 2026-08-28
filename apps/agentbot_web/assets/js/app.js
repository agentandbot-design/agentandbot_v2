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

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: { ChatScroll, RememberName },
})

// Connect
liveSocket.connect()

// expose for debugging
window.liveSocket = liveSocket
