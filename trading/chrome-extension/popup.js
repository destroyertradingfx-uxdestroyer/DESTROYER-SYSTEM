// popup.js — Popup UI controller
document.addEventListener("DOMContentLoaded", async () => {
    const statusBadge = document.getElementById("statusBadge");
    const mainToggle = document.getElementById("mainToggle");
    const webhookUrlInput = document.getElementById("webhookUrl");
    const tokenInput = document.getElementById("token");
    const pollIntervalSelect = document.getElementById("pollInterval");
    const saveBtn = document.getElementById("saveBtn");
    const scrapeBtn = document.getElementById("scrapeNow");
    const logArea = document.getElementById("log");

    function addLog(msg) {
        const entry = document.createElement("div");
        entry.className = "log-entry";
        entry.textContent = `[${new Date().toLocaleTimeString()}] ${msg}`;
        logArea.prepend(entry);
        if (logArea.children.length > 20) {
            logArea.removeChild(logArea.lastChild);
        }
    }

    // Load current config
    function loadConfig() {
        chrome.runtime.sendMessage({ action: "get-config" }, (response) => {
            if (response?.ok) {
                const config = response.config;
                webhookUrlInput.value = config.webhookUrl || "";
                tokenInput.value = config.token || "";
                pollIntervalSelect.value = config.pollIntervalMinutes || 1;
                mainToggle.classList.toggle("on", config.enabled);
                statusBadge.textContent = config.enabled ? "ACTIVE" : "OFF";
                statusBadge.classList.toggle("active", config.enabled);
                addLog("Config loaded");
            }
        });
    }

    // Toggle main switch
    mainToggle.addEventListener("click", () => {
        mainToggle.classList.toggle("on");
        const enabled = mainToggle.classList.contains("on");
        chrome.runtime.sendMessage({
            action: "update-config",
            config: { enabled }
        });
        statusBadge.textContent = enabled ? "ACTIVE" : "OFF";
        statusBadge.classList.toggle("active", enabled);
        addLog(`Monitoring ${enabled ? "enabled" : "disabled"}`);
    });

    // Save config
    saveBtn.addEventListener("click", () => {
        chrome.runtime.sendMessage({
            action: "update-config",
            config: {
                webhookUrl: webhookUrlInput.value.trim(),
                token: tokenInput.value.trim(),
                pollIntervalMinutes: parseFloat(pollIntervalSelect.value)
            }
        }, (response) => {
            if (response?.ok) {
                addLog("Config saved ✓");
                saveBtn.textContent = "Saved ✓";
                setTimeout(() => { saveBtn.textContent = "Save Config"; }, 1500);
            }
        });
    });

    // Scrape now
    scrapeBtn.addEventListener("click", () => {
        chrome.runtime.sendMessage({ action: "scrape-now" }, (response) => {
            if (response?.sent) {
                addLog(`Pushed: ${response.symbol} → ${response.status}`);
            } else if (response?.skipped) {
                addLog("Monitoring disabled — check toggle");
            } else {
                addLog(`Error: ${response?.error || "unknown"}`);
            }
        });
    });

    loadConfig();
});
