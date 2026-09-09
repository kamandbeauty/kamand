(function () {
  function ready(fn) {
    if (document.readyState !== 'loading') fn();
    else document.addEventListener('DOMContentLoaded', fn);
  }

  ready(function () {
    document.querySelectorAll('.saina-track').forEach(bindForm);
    document.addEventListener('click', function (e) {
      var btn = e.target.closest('.saina-confirm');
      if (!btn || !window.sainaTO) return;
      e.preventDefault();
      var fd = new FormData();
      fd.append('action', 'saina_confirm_delivery');
      fd.append('nonce', sainaTO.nonce);
      fd.append('order_id', btn.getAttribute('data-order'));
      fetch(sainaTO.ajax, { method: 'POST', body: fd, credentials: 'same-origin' })
        .then(function (r) { return r.json(); })
        .then(function (res) {
          if (res.success && res.data.html) {
            var card = btn.closest('.saina-card');
            if (card) card.outerHTML = res.data.html;
          } else {
            alert((res.data && res.data.message) || 'خطا');
          }
        });
    });
  });

  function bindForm(root) {
    var form = root.querySelector('.saina-track-form');
    var results = root.querySelector('.saina-results');
    var tabs = root.querySelectorAll('.saina-tabs button');
    var capQ = root.querySelector('.saina-captcha-q');
    var capH = root.querySelector('input[name="captcha_hash"]');
    if (capQ && window.sainaTO) capQ.textContent = sainaTO.captchaLabel;
    if (capH && window.sainaTO) capH.value = sainaTO.captchaHash;

    function showTab(tab) {
      root.querySelector('.saina-f-order').style.display = tab === 'mobile' || tab === 'email' ? 'none' : '';
      root.querySelector('.saina-f-mobile').style.display = tab === 'order' || tab === 'email' ? 'none' : '';
      root.querySelector('.saina-f-email').style.display = tab === 'order' || tab === 'mobile' ? 'none' : '';
    }
    showTab('order');
    tabs.forEach(function (btn) {
      btn.addEventListener('click', function () {
        tabs.forEach(function (b) { b.classList.remove('is-active'); });
        btn.classList.add('is-active');
        showTab(btn.getAttribute('data-tab'));
      });
    });

    form.addEventListener('submit', function (e) {
      e.preventDefault();
      if (!window.sainaTO) return;
      var fd = new FormData(form);
      fd.append('action', 'saina_track_order');
      fd.append('nonce', sainaTO.nonce);
      results.innerHTML = '<p class="saina-muted">در حال جستجو…</p>';
      fetch(sainaTO.ajax, { method: 'POST', body: fd, credentials: 'same-origin' })
        .then(function (r) { return r.json(); })
        .then(function (res) {
          if (res.success) results.innerHTML = res.data.html;
          else results.innerHTML = '<div class="saina-error">' + (res.data && res.data.message ? res.data.message : 'سفارش یافت نشد') + '</div>';
        })
        .catch(function () {
          results.innerHTML = '<div class="saina-error">خطای ارتباط با سرور</div>';
        });
    });
  }
})();
