// DESTROYER — Service Worker (Background)
// Manages config, periodic scraping, and data push to VPS

const DEFAULT_CONFIG = {
  // Your ngrok HTTPS URL (or your VPS hostname when you get a domain/HTTPS cert)
  webhookUrl: "https://unkemptly-chivalrous-karon.ngrok-free.dev/signal",
  // Alternative: direct HTTP to your VPS if using HTTP
  // webhookUrl: "http://16.170.225.77:8721/signal",
  token: "destroyer-sig-2026",
  pollIntervalMinutes: 1,
  enabled: true
};

// Load config from storage
async function getConfig() {
  const result = await chrome.storage.sync.get("config");
  return { ...DEFAULT_CONFIG, ...(result.config || {}) };
}

// Save config to storage
async function setConfig(partial) {
  const current = await getConfig();
  await chrome.storage.sync.set({ config: { ...current, ...partial } });
  return { ...current, ...partial };
}

// Extract chart data from a TradingView tab
async function scrapeChartTab(tabId) {
  try {
    const results = await chrome.scripting.executeScript({
      target: { tabId },
      func: () => {
        // This runs in the TradingView page context
        const data = {
          symbol: "unknown",
          timeframe: "unknown",
          indicators: [],
          price: {},
          pageTitle: document.title,
          url: window.location.href,
          scrapedAt: new Date().toISOString()
        };

        // Get symbol from URL
        const urlMatch = window.location.href.match(/symbol=([^&]+)/);
        if (urlMatch) {
          try {
            data.symbol = decodeURIComponent(urlMatch[1]);
          } catch(e) {}
        }

        // Get from page title as backup
        if (data.symbol === "unknown") {
          const parts = document.title.split("-");
          data.symbol = parts[0].trim();
        }

        // Scrape status bar (OHLCV data)
        const statusBar = document.querySelector(".status-line, .chart-bottom-toolbar .status-line, [class*='status-line']");
        if (statusBar) {
          data.price.rawStatusBar = statusBar.textContent?.trim().substring(0, 200);
        }

        // Scrape price label
        const priceLabel = document.querySelector(".header-chart-toolbar__last, .last, [class*='last-price']");
        if (priceLabel) {
          data.price.current = priceLabel.textContent?.trim();
        }

        // Scrape change
        const changeLabel = document.querySelector(".header-chart-toolbar__change, [class*='change']");
        if (changeLabel) {
          data.price.change = changeLabel.textContent?.trim();
        }

        // Scrape study legend (indicator names)
        const legends = document.querySelectorAll(".study-legend-item, .legend-source-item, [class*='study-title'], [class*='pane-legend']");
        legends.forEach(leg => {
          const name = leg.textContent?.trim();
          if (name && name.length > 1 && name.length < 100) {
            data.indicators.push({ name, value: "active", source: "legend" });
          }
        });

        // Scrape data window panel
        const dataWindows = document.querySelectorAll(".data-window, .source-properties-pane, [class*='data-window'], [class*='property-page']");
        dataWindows.forEach(dw => {
          // Try to find label-value pairs
          const rows = dw.querySelectorAll("tr, .data-window-row, .row, [class*='row']");
          rows.forEach(row => {
            const text = row.textContent?.trim();
            if (text && text.length > 2 && text.length < 200) {
              data.indicators.push({ name: "data-window", value: text, source: "data-panel" });
            }
          });

          // Get all text content from data window
          const fullText = dw.textContent?.trim();
          if (fullText && fullText.length > 10 && fullText.length < 5000) {
            data.dataWindowContent = fullText.substring(0, 4000);
          }
        });

        // Scrape strategy tester results
        const strategyPanel = document.querySelector("[class*='strategy-result'], [class*='strategy-report'], [data-name='m_StudyGroupStrategy']");
        if (strategyPanel) {
          data.strategyResults = {
            visible: true,
            content: strategyPanel.textContent?.trim().substring(0, 2000)
          };
        }

        // Get active timeframe from URL or UI
        const tfMatch = window.location.href.match(/[?&]interval=([^&]+)/);
        if (tfMatch) {
          data.timeframe = tfMatch[1];
        }

        // Try to get timeframe from active button
        const intervalBtns = document.querySelectorAll("[class*='interval'], [data-role='interval']");
        intervalBtns.forEach(btn => {
          if (btn.classList.contains("selected") || btn.classList.contains("active") ||
              btn.getAttribute("aria-pressed") === "true") {
            data.timeframe = btn.textContent?.trim() || data.timeframe;
          }
        });

        // Get chart region screenshot data (if possible)
        const canvas = document.querySelector("canvas.chart-canvas");
        if (canvas) {
          try {
            data.hasChartScreenshot = true;
            // We'll skip the actual screenshot for bandwidth, but note it exists
          } catch(e) {}
        }

        return data;
      }
    });

    return results[0]?.result || null;
  } catch (e) {
    console.error("[DESTROYER] Scrape error:", e);
    return { error: e.message };
  }
}

// Send data to webhook server
async function pushToVPS(chartData) {
  const config = await getConfig();
  if (!config.enabled) return { skipped: true };

  const payload = {
    signal_id: `tv-ext-${Date.now()}`,
    symbol: chartData.symbol,
    timeframe: chartData.timeframe,
    price: chartData.price,
    indicators: chartData.indicators,
    dataWindow: chartData.dataWindowContent,
    strategyResults: chartData.strategyResults,
    page_title: chartData.pageTitle,
    page_url: chartData.url,
    scraped_at: chartData.scrapedAt,
    _source: "chrome-extension"
  };

  try {
    const response = await fetch(config.webhookUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Signal-Token": config.token,
        "ngrok-skip-browser-warning": "true"
      },
      body: JSON.stringify(payload)
    });

    const status = response.status;
    let result = {};
    try {
      result = await response.json();
    } catch(e) {
      // ngrok might return HTML
      result = { raw_response_status: status };
    }

    return {
      sent: true,
      status,
      symbol: chartData.symbol,
      response: result
    };
  } catch (e) {
    return { sent: false, error: e.message };
  }
}

// Check for TradingView tabs and scrape them
async function scrapeAllTVTabs() {
  const config = await getConfig();
  if (!config.enabled) return;

  const tabs = await chrome.tabs.query({ url: "https://www.tradingview.com/chart/*" });
  if (tabs.length === 0) return;

  for (const tab of tabs) {
    const data = await scrapeChartTab(tab.id);
    if (data && !data.error) {
      const result = await pushToVPS(data);
      console.log(`[DESTROYER] ${tab.title}:`, result);

      // Update badge
      chrome.action.setBadgeText({ text: "✅", tabId: tab.id });
      setTimeout(() => {
        chrome.action.setBadgeText({ text: "", tabId: tab.id });
      }, 3000);
    }
  }
}

// Set up periodic polling
async function setupPolling() {
  await chrome.alarms.clearAll();
  const config = await getConfig();
  const interval = Math.max(config.pollIntervalMinutes, 0.5); // minimum 30 seconds

  chrome.alarms.create("destroyer-poll", {
    periodInMinutes: interval
  });

  console.log(`[DESTROYER] Polling every ${interval} minutes`);
}

// Event listeners
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "destroyer-poll") {
    scrapeAllTVTabs();
  }
});

// When extension is installed/updated
chrome.runtime.onInstalled.addListener(async () => {
  await setConfig(DEFAULT_CONFIG);
  await setupPolling();

  // Set up the popup icon
  chrome.action.setBadgeBackgroundColor({ color: "#1a1a2e" });

  console.log("[DESTROYER] Extension installed and configured");
});

// Start polling on launch
chrome.runtime.onStartup.addListener(async () => {
  await setupPolling();
  setTimeout(() => scrapeAllTVTabs(), 5000);
});

// Manual scrape via message
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === "scrape-now") {
    scrapeAllTVTabs().then(result => {
      sendResponse(result);
    });
    return true; // async response
  }

  if (message.action === "update-config") {
    setConfig(message.config).then(updated => {
      setupPolling();
      sendResponse({ ok: true, config: updated });
    });
    return true;
  }

  if (message.action === "get-config") {
    getConfig().then(config => {
      sendResponse({ ok: true, config });
    });
    return true;
  }
});

// Log startup
console.log("[DESTROYER] Extension loaded. TradingView monitoring active.");
