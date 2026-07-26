/**
 * Havato Frontend Application - Production Ready
 * Integrates full Customer Portal
 */
(function() {
    'use strict';

    window.HavatoApp = {
        currentTab: 'explore',

        init: function() {
            this.bindNavigation();
            this.loadTab(this.currentTab);
            
            // Load customer portal module
            if (window.HavatoCustomer) {
                window.HavatoCustomer.init();
            }
        },

        bindNavigation: function() {
            const navItems = document.querySelectorAll('.nav-item');
            navItems.forEach(item => {
                item.addEventListener('click', () => {
                    navItems.forEach(el => el.classList.remove('active'));
                    item.classList.add('active');
                    const tab = item.dataset.tab;
                    this.loadTab(tab);
                });
            });
        },

        async loadTab(tab) {
            this.currentTab = tab;
            const contentEl = document.getElementById('havato-tab-content');
            if (!contentEl) return;

            contentEl.innerHTML = '<div class="loading p-8 text-center">Loading...</div>';

            try {
                let html = '';
                const customer = window.HavatoCustomer || {};

                switch (tab) {
                    case 'explore':
                        html = await customer.renderExplore?.() || await this.renderExploreFallback();
                        contentEl.innerHTML = html;
                        if (customer.bindExploreEvents) customer.bindExploreEvents(contentEl);
                        break;

                    case 'map':
                        html = customer.renderMap?.() || this.renderMapFallback();
                        contentEl.innerHTML = html;
                        if (customer.initLeafletMap) setTimeout(() => customer.initLeafletMap(), 300);
                        break;

                    case 'chats':
                        html = await customer.renderChats?.() || `<div class="glass p-6">Chats loading...</div>`;
                        contentEl.innerHTML = html;
                        if (customer.initChats) customer.initChats();
                        break;

                    case 'profile':
                        html = await customer.renderProfile?.() || `<div class="glass p-6">Profile loading...</div>`;
                        contentEl.innerHTML = html;
                        if (customer.bindProfileEvents) customer.bindProfileEvents(contentEl);
                        break;
                }
            } catch (e) {
                contentEl.innerHTML = '<p class="p-8 text-center text-red-400">Error loading content.</p>';
                console.error(e);
            }
        },

        // Fallbacks (in case customer module not loaded)
        async renderExploreFallback() {
            const res = await fetch('/wp-json/havato/v1/events');
            const json = await res.json();
            const events = json.data || [];
            if (!events.length) return `<div class="glass p-8 text-center">No open events right now.</div>`;
            return events.map(e => `<div class="event-card glass"><h3>${e.title}</h3></div>`).join('');
        },

        renderMapFallback() {
            return `<div class="glass p-4"><h3>Map View</h3><div id="havato-leaflet-map" style="height:420px;background:#111827;border-radius:20px;"></div></div>`;
        }
    };
})();