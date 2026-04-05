/**
 * DESTROYER TV Data Pusher — v2
 * Scrapes indicator values, OHLC, drawings, and strategy data from TradingView.
 * Uses both DOM scraping + JS internals when available.
 */
(function() {
    const CONFIG = {
        URL: "https://unkemptly-chivalrous-karon.ngrok-free.dev/signal",
        TOKEN: "destroyer-sig-2026"
    };

    // ========== Data Extraction ==========

    function getWidgetInfo() {
        // Try to access TV's internal widget state
        try {
            // Look for TradingView widget instance
            for (const key of Object.keys(window)) {
                if (key.startsWith('tradingview_') || key.startsWith('widget_')) {
                    const w = window[key];
                    if (w && typeof w === 'object' && w.chart) {
                        return w;
                    }
                }
            }

            // Check for widgetInstance or similar patterns
            if (window.widgetInstance) return window.widgetInstance;
            if (window.TV && TV.widget) return TV.widget;
            if (window.widget && typeof widget === 'object') return widget;

        } catch(e) {}
        return null;
    }

    function extractOHLC() {
        const data = { open: null, high: null, low: null, close: null, volume: null };

        // Method 1: Status bar (bottom-left of chart)
        const statusLine = document.querySelector('.status-line, .chart-bottom-toolbar .status-line');
        if (statusLine) {
            const text = statusLine.textContent || '';
            // Pattern: open, high, low, close, volume
            const numbers = text.match(/[Oo]pen[:\s]*([\d,.]+)|[Hh]igh[:\s]*([\d,.]+)|[Ll]ow[:\s]*([\d,.]+)|[Cc]lose[:\s]*([\d,.]+)/g);
            if (numbers) {
                const o = text.match(/[Oo]pen[:\s]*([\d,.]+)/);
                const h = text.match(/[Hh]igh[:\s]*([\d,.]+)/);
                const l = text.match(/[Ll]ow[:\s]*([\d,.]+)/);
                const c = text.match(/[Cc]lose[:\s]*([\d,.]+)/);
                if (o) data.open = o[1].replace(',','');
                if (h) data.high = h[1].replace(',','');
                if (l) data.low = l[1].replace(',','');
                if (c) data.close = c[1].replace(',','');
            }
        }

        // Method 2: Price label in chart (top-right area)
        const priceEl = document.querySelector('.last, .price-axis .price-label, .header-chart-toolbar__last');
        if (!data.close && priceEl) {
            data.close = priceEl.textContent?.replace(/[^0-9.]/g, '');
        }

        // Method 3: Crosshair value
        const crosshair = document.querySelector('.crosshair-legend .legend-source-item-label');
        if (!data.close && crosshair) {
            const parent = crosshair.closest('.crosshair-legend, .study-legend');
            if (parent) {
                data.crosshair = parent.textContent?.substring(0, 200);
            }
        }

        // Method 4: Any price display
        const priceChange = document.querySelector('.header-chart-toolbar__last')?.textContent;
        if (priceChange && !data.close) {
            data.raw = priceChange.replace(/\s/g, ' ').trim();
        }

        const changeEl = document.querySelector('.header-chart-toolbar__change-value, .header-symbol-text');
        if (changeEl) {
            data.change = changeEl.textContent?.trim();
        }

        // Clean up
        return Object.fromEntries(
            Object.entries(data).filter(([k,v]) => v !== null && v !== undefined && v !== '')
        );
    }

    function extractIndicators() {
        const indicators = [];

        // Method 1: Data window panel (right side)
        // TradingView shows indicator values for the current bar here
        const dataWindowContainers = document.querySelectorAll(
            '[class*="data-window"], .data-window, .data-window-content, ' +
            '[class*="source-properties-pane"], .source-properties-pane, ' +
            '[class*="property-page-section"], .property-page__content'
        );

        dataWindowContainers.forEach(container => {
            // Each row is typically: label + value
            const rows = container.querySelectorAll('[class*="row"], .data-window__row, ' +
                '[class*="data-legend-row"], [class*="value-cell"], ' +
                '[class*="source-properties-row"], tr, div');

            rows.forEach(row => {
                // Try to find label-value pairs
                const labels = row.querySelectorAll('[class*="title"], [class*="name"], ' +
                    '[class*="label"], [class*="source-title"], td:first-child');
                const values = row.querySelectorAll('[class*="value"], [class*="data"], ' +
                    '[class*="source-value"], td:last-child, .data-window__row-value');

                labels.forEach((label, i) => {
                    const lName = label.textContent?.trim();
                    const lValue = values[i]?.textContent?.trim() ||
                                   row.textContent?.substring(lName.length).trim();

                    if (lName && lValue && lName.length > 1 && lName.length < 100) {
                        indicators.push({
                            name: lName,
                            value: lValue,
                            source: 'data-window'
                        });
                    }
                });
            });
        });

        // Method 2: Study legend (top-left overlays showing indicator names)
        const studyItems = document.querySelectorAll(
            '.studylegend, [class*="study-legend-item"], [class*="legend-source-item"], ' +
            '[class*="study-title"], .study-controls .source'
        );

        studyItems.forEach(item => {
            const name = item.textContent?.trim();
            if (name && name.length > 1 && !indicators.some(i => i.name === name)) {
                indicators.push({
                    name: name,
                    value: 'enabled',
                    source: 'legend'
                });
            }
        });

        // Method 3: Indicator values shown directly on chart (labels, lines)
        const chartLabels = document.querySelectorAll(
            '.pine-label, .price-axis .price-line, .price-label, ' +
            '[class*="line-source-label"], [class*="study-source-label"]'
        );

        chartLabels.forEach(label => {
            const text = label.textContent?.trim();
            if (text && text.length > 2 && !indicators.some(i => i.name === text)) {
                indicators.push({
                    name: 'label_on_chart',
                    value: text,
                    source: 'chart-label'
                });
            }
        });

        return indicators;
    }

    function extractSymbolAndTimeframe() {
        // Get from URL: /chart/XXXX/SYMBOL?
        const urlParts = window.location.href.split('/');
        let symbol = urlParts.find(p => p.includes(':') || p.includes('GOLD')) || '';
        if (!symbol) {
            symbol = document.querySelector('.symbol-edit .text, .chart-page-title, [class*="symbol-name"]')?.textContent?.trim();
        }
        if (!symbol) symbol = document.title?.split('-')[0]?.trim() || 'Unknown';

        // Timeframe from URL
        const tfMatch = window.location.href.match(/[?&]interval=([^&]+)/);
        const timeframe = tfMatch ? tfMatch[1] :
            (window.performance?.getEntriesByType('navigation')?.[0]?.referer ? '' : '');

        // Try to get timeframe from active button
        const tfBtns = document.querySelectorAll('.chart-controls .button, [class*="interval"], [data-role="interval"]');
        tfBtns.forEach(btn => {
            if (btn.classList.contains('selected') || btn.classList.contains('active') ||
                btn.getAttribute('aria-pressed') === 'true') {
                tfBtns._active = btn.textContent?.trim();
            }
        });

        return {
            symbol: symbol.replace(/\s+/g, ' ').trim(),
            timeframe: tfBtns._active || timeframe || 'Unknown',
            full_url: window.location.href
        };
    }

    function extractStrategyResults() {
        const strategyData = {};

        // Strategy tester panel (if open)
        const results = document.querySelectorAll(
            '[class*="strategy-reporter"], [class*="strategy-results"], ' +
            '.strategy-tester-panel__results, [class*="test-results"]'
        );

        results.forEach(container => {
            const items = container.querySelectorAll(
                '[class*="result-item"], [class*="result-row"], tr, div'
            );

            items.forEach(item => {
                const text = item.textContent?.trim();
                if (text) {
                    // Try to parse "Net Profit: 123.45" or similar patterns
                    const match = text.match(/^([^:]+):\s*([-\d,.%$]+)/);
                    if (match) {
                        strategyData[match[1].trim()] = match[2].trim();
                    } else {
                        strategyData['raw_' + item.textContent.substring(0, 20)] = text;
                    }
                }
            });
        });

        // If we got nothing via DOM scraping, try to detect if strategy tester is visible
        const strategyPane = document.querySelector('[data-name="m_StudyGroupStrategy"]');
        if (strategyPane && Object.keys(strategyData).length === 0) {
            strategyData._visible = true;
            strategyData._note = 'Strategy tester found but data not scrape-ready';
        }

        return strategyData;
    }

    // ========== Data Assembly & Push ==========

    function scrapeAll() {
        const symbolInfo = extractSymbolAndTimeframe();
        const ohlc = extractOHLC();
        const indicators = extractIndicators();
        const strategy = extractStrategyResults();

        return {
            signal_id: "tv-" + Date.now(),
            symbol: symbolInfo.symbol,
            timeframe: symbolInfo.timeframe,
            price: ohlc,
            indicators: indicators,
            strategyResults: Object.keys(strategy).length > 0 ? strategy : null,
            page_url: symbolInfo.full_url,
            scraped_at: new Date().toISOString(),
            _scrape_method: "dom-v2"
        };
    }

    function push(data) {
        const headers = {
            'Content-Type': 'application/json',
            'X-Signal-Token': CONFIG.TOKEN,
            'ngrok-skip-browser-warning': 'true'  // Skip ngrok's warning page
        };

        fetch(CONFIG.URL, { method: 'POST', headers: headers, body: JSON.stringify(data) })
            .then(r => {
                // ngrok shows a warning page as HTML - try to parse as JSON
                const ct = r.headers.get('content-type') || '';
                if (ct.includes('html')) {
                    return r.text().then(body => {
                        try {
                            // ngrok warning page - extract the error info
                            return { _ngrok_warning: true, raw_body: body.substring(0, 200) };
                        } catch(e) {
                            throw new Error('ngrok warning page');
                        }
                    });
                }
                return r.json();
            })
            .then(res => {
                showPopup('✅', 'green', `Pushed: ${data.symbol}`);
                console.log('DESTROYER Signal pushed:', res);
            })
            .catch(err => {
                showPopup('❌', 'red', 'Push failed - see console');
                console.error('DESTROYER Push error:', err);
            });
    }

    function showPopup(icon, color, message) {
        const existing = document.querySelector('#destroyer-popup');
        if (existing) existing.remove();

        const n = document.createElement('div');
        n.id = 'destroyer-popup';
        n.style.cssText = `position:fixed;top:20px;right:20px;padding:16px 24px;background:#1a1a2e;color:${color};border:2px solid ${color};border-radius:8px;z-index:999999;font:14px monospace;box-shadow:0 4px 20px rgba(0,0,0,0.5);`;
        n.innerHTML = `${icon} ${message}`;
        n.onclick = () => n.remove();
        document.body.appendChild(n);

        // Copy data to clipboard for verification
        const data = scrapeAll();
        const clipboard = JSON.stringify(data, null, 2).substring(0, 500);
        navigator.clipboard?.writeText(clipboard).then(() => {
            n.title = 'Data copied to clipboard (first 500 chars)';
        });

        setTimeout(() => n.remove(), 5000);
    }

    // Run
    const data = scrapeAll();
    console.log('DESTROYER v2 scraped:', data);
    push(data);
})();
