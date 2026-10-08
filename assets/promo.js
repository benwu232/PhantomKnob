(function() {
  var promoData = {
    active: true,
    code: "QYNDIWMW",
    deadline: "2026-11-09T00:00:00Z",
    checkoutBaseUrl: "https://benwu232.lemonsqueezy.com/checkout/buy/da9296da-8b59-44d6-bac5-e6c36714fdbc"
  };

  function applyPromo(data) {
    var now = new Date();
    var deadline = new Date(data.deadline);
    var isExpired = !data.active || now >= deadline;
    var promoBanner = document.getElementById("promo-banner");
    var promoBox = document.getElementById("promo-coupon-box");
    var promoTag = document.getElementById("pro-promo-tag");
    var saveBadge = document.getElementById("pro-save-badge");
    var origPrice = document.getElementById("pro-orig-price");
    var curPrice = document.getElementById("pro-cur-price");
    var deadlineText = document.getElementById("pro-deadline-text");
    var buyBtn = document.getElementById("buy-pro-btn");
    var isZh = document.documentElement.lang.indexOf("zh") !== -1;

    if (isExpired) {
      if (promoBanner) promoBanner.style.display = "none";
      if (promoBox) promoBox.style.display = "none";
      if (promoTag) promoTag.style.display = "none";
      if (saveBadge) saveBadge.style.display = "none";
      if (origPrice) origPrice.style.display = "none";
      if (deadlineText) deadlineText.style.display = "none";
      if (curPrice) {
        var tipText = isZh ? "e = 2.718281... 自然底数" : "e = 2.718281... Natural Base";
        curPrice.innerHTML = '$27.18<span class="math-const">10e</span><span class="tip-box">' + tipText + '</span>';
      }
      if (buyBtn) buyBtn.href = data.checkoutBaseUrl;
    } else {
      if (buyBtn) {
        buyBtn.href = data.checkoutBaseUrl + "?checkout[discount_code]=" + encodeURIComponent(data.code);
      }
    }
  }

  function initCopy() {
    var copyBtn = document.getElementById("promo-copy-btn");
    var codeVal = document.getElementById("promo-code-val");
    if (copyBtn && codeVal) {
      copyBtn.addEventListener("click", function() {
        var text = codeVal.innerText.trim();
        var isZh = document.documentElement.lang.indexOf("zh") !== -1;
        var copiedLabel = isZh ? "已复制!" : "Copied!";
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(function() {
            var origHTML = copyBtn.innerHTML;
            copyBtn.classList.add("copied");
            copyBtn.innerHTML = "<span>" + copiedLabel + "</span>";
            setTimeout(function() {
              copyBtn.classList.remove("copied");
              copyBtn.innerHTML = origHTML;
            }, 2000);
          });
        }
      });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function() {
      initCopy();
      fetch("promo.json").then(function(r) { return r.json(); }).then(applyPromo).catch(function() { applyPromo(promoData); });
    });
  } else {
    initCopy();
    fetch("promo.json").then(function(r) { return r.json(); }).then(applyPromo).catch(function() { applyPromo(promoData); });
  }
})();
