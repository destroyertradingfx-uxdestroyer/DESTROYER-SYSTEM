// injector.js — Injected into TradingView pages
(function() {
    if (!document.body) return;

    // Check if already injected
    if (window.__destroyer_injected) return;
    window.__destroyer_injected = true;

    console.log("[DESTROYER] Injector active on", window.location.href);

    // Notify the background service worker that this tab has TV data
    chrome.runtime.sendMessage({
        action: "tv-tab-detected",
        url: window.location.href,
        title: document.title
    });
})();
