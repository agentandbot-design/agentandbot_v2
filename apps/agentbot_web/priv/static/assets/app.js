// AgentAndBot — Phoenix LiveView init
(function() {
  function initLiveSocket() {
    if (typeof LiveView === 'undefined' || typeof Phoenix === 'undefined') {
      setTimeout(initLiveSocket, 50);
      return;
    }

    var csrfToken = document.querySelector("meta[name='csrf-token']");
    if (!csrfToken) return;

    var liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
      params: { _csrf_token: csrfToken.getAttribute("content") }
    });

    liveSocket.connect();
    window.liveSocket = liveSocket;
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initLiveSocket);
  } else {
    initLiveSocket();
  }
})();
