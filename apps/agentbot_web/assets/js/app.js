// AgentAndBot — Phoenix LiveView app.js
// esbuild ile derlenir

import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

// CSRF token
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// LiveSocket init
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken }
})

// Connect
liveSocket.connect()

// expose for debugging
window.liveSocket = liveSocket
