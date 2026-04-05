/**
 * DESTROYER TradingView Bookmarklet
 * 
 * Drag this to your bookmarks bar or paste in JS console.
 * Scrapes indicator data from active TradingView chart and POSTs to your VPS.
 * 
 * CONFIG: Change VPS_URL and TOKEN below.
 */
(function() {
    const CONFIG = {
        VPS_URL: "http://172.31.40.81:8471/signal",
        TOKEN: "destroyer-signal-2026",
        INTERVAL_MS: 60000  // Push every 60s when active
    };

    let pusher = null;

    function getChartSymbol() {
        // Try to extract symbol from TradingView page
        const titleEl = document.querySelector('.chart-page .symbol-edit-widget .symbol-edit-widget__text');
        const headerEl = document.querySelector('.header-chart-toolbar__symbol .header-chart-toolbar__symbol--label span');
        const urlMatch = window.location.href.match(/\/symbol\/([A-Z0-9:]+)/i);
        return titleEl?.textContent?.trim() || headerEl?.textContent?.trim() || urlMatch?.[1] || 'UNKNOWN';
    }

    function getChartTimeframe() {
        // Extract timeframe from URL or DOM
        const urlMatch = window.location.href.match(/\/([A-Z0-9]+)\/([A-Z0-9:]+)\?/);
        return urlMatch?.[1] || 'Unknown';
    }

    function scrapeIndicatorValues() {
        const indicators = [];
        
        // Scrape all indicator values from the data window
        const dataWindows = document.querySelectorAll('.source-properties-pane, .data-window');
        dataWindows.forEach(dw => {
            const rows = dw.querySelectorAll('.data-window__row, .source-properties-pane__content-list-source-properties-row');
            rows.forEach(row => {
                const name = row.querySelector('.data-window__row-name, .source-properties-pane__content-list-source-properties-row-title')?.textContent?.trim();
                const value = row.querySelector('.data-window__row-value, .source-properties-pane__content-list-source-properties-row-value')?.textContent?.trim();
                if (name && value) {
                    indicators.push({ name, value });
                }
            });
        });

        // Scrape drawing objects (support/resistance lines, labels)
        const drawings = [];
        const labels = document.querySelectorAll('.label-widget');
        labels.forEach(label => {
            const text = label.textContent?.trim();
            if (text) drawings.push({ type: 'label', content: text });
        });

        // Scrape strategy tester results if panel is visible
        const strategyPanel = document.querySelector('[data-name="m_StudyGroupStrategy"]');
        let strategyResults = null;
        if (strategyPanel) {
            const resultItems = document.querySelectorAll('[data-name="strategies-results-item__description-value"], [data-name="net-profit-value"]');
            strategyResults = {};
            resultItems.forEach(item => {
                const name = item.previousElementSibling?.textContent?.trim() || 'result';
                strategyResults[name] = item.textContent?.trim();
            });
        }

        return { indicators, drawings, strategyResults };
    }

    function scrapePriceAction() {
        const ohlc = {};
        
        // Get price info from the header
        const priceEls = document.querySelectorAll('.header-chart-toolbar__last, .header-chart-toolbar__change-value');
        if (priceEls.length > 0) {
            ohlc.price = priceEls[0]?.textContent?.trim();
            ohlc.change = priceEls[1]?.textContent?.trim();
        }

        // Get OHLC from status bar if available
        const ohlcEl = document.querySelector('.status-line, .bar-mark-text');
        if (ohlcEl) {
            const text = ohlcEl.textContent?.trim();
            ohlc.rawStatus = text;
        }

        return ohlc;
    }

    function scrapeChart() {
        const symbol = getChartSymbol();
        const timeframe = getChartTimeframe();
        const scraped = scrapeIndicatorValues();
        const price = scrapePriceAction();

        return {
            symbol,
            timeframe,
            price,
            indicators: scraped.indicators,
            drawings: scraped.drawings,
            strategyResults: scraped.strategyResults,
            page_url: window.location.href,
            scraped_at: new Date().toISOString()
        };
    }

    function pushToVPS(data) {
        fetch(CONFIG.VPS_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Signal-Token': CONFIG.TOKEN
            },
            body: JSON.stringify(data)
        })
        .then(r => r.json())
        .then(resp => {
            console.log('✅ DESTROYER Signal pushed:', resp);
        })
        .catch(err => {
            console.error('❌ DESTROYER Push failed:', err);
        });
    }

    function togglePusher() {
        if (pusher) {
            clearInterval(pusher);
            pusher = null;
            console.log('⏸ DESTROYER Auto-push stopped');
            return;
        }

        console.log('▶ DESTROYER Auto-push started (' + (CONFIG.INTERVAL_MS/1000) + 's interval)');
        
        // Push immediately, then on interval
        pushToVPS(scrapeChart());
        pusher = setInterval(() => {
            pushToVPS(scrapeChart());
        }, CONFIG.INTERVAL_MS);
    }

    // Run main function
    togglePusher();
})();
