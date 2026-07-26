/**
 * Havato Cafe Owner Portal JS
 */
(function() {
    window.HavatoCafeOwner = {
        init() {
            this.bindNavigation();
            this.loadTab('dashboard');
        },

        bindNavigation() {
            document.querySelectorAll('.nav-item').forEach(item => {
                item.addEventListener('click', () => {
                    document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
                    item.classList.add('active');
                    this.loadTab(item.dataset.tab);
                });
            });
        },

        async loadTab(tab) {
            const container = document.getElementById('cafe-owner-content');
            if (!container) return;

            container.innerHTML = '<div class="loading p-8 text-center">Loading...</div>';

            let html = '';
            switch (tab) {
                case 'dashboard':
                    html = await this.renderDashboard();
                    break;
                case 'events':
                    html = await this.renderEvents();
                    break;
                case 'menu':
                    html = this.renderMenuBuilder();
                    break;
                case 'venue':
                    html = await this.renderVenueSettings();
                    break;
            }
            container.innerHTML = html;
        },

        async renderDashboard() {
            return `
                <div class="glass p-6">
                    <h2>Dashboard</h2>
                    <div class="grid grid-cols-2 gap-4 mt-6">
                        <div class="glass p-4"><div class="text-3xl font-bold">124</div><div class="text-sm">Total Guests</div></div>
                        <div class="glass p-4"><div class="text-3xl font-bold">87%</div><div class="text-sm">Utilization</div></div>
                    </div>
                </div>
            `;
        },

        async renderEvents() {
            return `<div class="glass p-6">Your events will appear here with member lists and preorders.</div>`;
        },

        renderMenuBuilder() {
            return `
                <div class="glass p-6">
                    <h3>Menu Builder</h3>
                    <div class="mt-4">
                        <input type="text" placeholder="Item name" class="glass w-full px-4 py-3 rounded-2xl mb-3">
                        <input type="number" placeholder="Price" class="glass w-full px-4 py-3 rounded-2xl mb-3">
                        <button class="btn btn-primary w-full">Add Item (Pending Approval)</button>
                    </div>
                </div>
            `;
        },

        async renderVenueSettings() {
            return `
                <div class="glass p-6">
                    <h3>Venue Settings</h3>
                    <form id="venue-form">
                        <input type="text" name="name" placeholder="Cafe Name" class="glass w-full px-4 py-3 rounded-2xl mb-3">
                        <input type="text" name="address" placeholder="Address" class="glass w-full px-4 py-3 rounded-2xl mb-3">
                        <div id="venue-map" style="height:280px;border-radius:16px;background:#111827;margin:20px 0;"></div>
                        <button type="submit" class="btn btn-primary w-full">Save Settings</button>
                    </form>
                </div>
            `;
        }
    };
})();