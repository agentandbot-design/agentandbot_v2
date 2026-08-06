// AgentAndBot — Phoenix LiveView init + form helper
(function() {
  function init() {
    if (typeof LiveView === 'undefined' || typeof Phoenix === 'undefined') {
      setTimeout(init, 50);
      return;
    }

    var csrfToken = document.querySelector("meta[name='csrf-token']");
    if (!csrfToken) return;

    var liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
      params: { _csrf_token: csrfToken.getAttribute("content") }
    });

    liveSocket.connect();
    window.liveSocket = liveSocket;

    // LiveView event'leri DOM'a bind edilene kadar bekle
    // sonra form'ları manuel intercept et
    setTimeout(bindFormFallbacks, 1000);
  }

  // Fallback: LiveView phx-submit çalışmazsa manuel yakala
  function bindFormFallbacks() {
    document.querySelectorAll('form[phx-submit]').forEach(function(form) {
      if (form.dataset.fallbackBound) return;
      form.dataset.fallbackBound = '1';

      form.addEventListener('submit', function(e) {
        // LiveView zaten handle ediyorsa dokunma
        if (e.defaultPrevented) return;

        e.preventDefault();
        e.stopPropagation();

        // LiveView channel üzerinden push et
        var liveSocket = window.liveSocket;
        var rootEl = document.querySelector('[data-phx-session]');
        if (!liveSocket || !rootEl) return;

        var view = liveSocket.getViewByEl(rootEl);
        if (!view) return;

        // Form data topla
        var params = {};
        new FormData(form).forEach(function(v, k) { params[k] = v; });

        // Channel üzerinden event push
        var channel = view.channel;
        channel.push('event', {
          type: 'submit',
          event: form.getAttribute('phx-submit'),
          value: params
        });

        // Input'u temizle
        var contentInput = form.querySelector('input[name="content"]');
        if (contentInput) contentInput.value = '';
      });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
