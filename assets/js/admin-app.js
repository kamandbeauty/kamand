(function (wp) {
    'use strict';

    if (!wp || !wp.element) {
        return;
    }

    var h = wp.element.createElement;
    var useEffect = wp.element.useEffect;
    var useState = wp.element.useState;
    var __ = wp.i18n && wp.i18n.__ ? wp.i18n.__ : function (text) { return text; };
    var root = document.getElementById('aiseocs-admin-app');

    if (!root) {
        return;
    }

    var config = {
        restUrl: root.getAttribute('data-rest-url'),
        nonce: root.getAttribute('data-nonce'),
        initialTab: root.getAttribute('data-initial-tab') || 'generator',
        locale: root.getAttribute('data-locale') || 'en_US',
        isRtl: root.getAttribute('data-is-rtl') === '1'
    };

    function api(path, options) {
        options = options || {};
        var headers = options.headers || {};
        headers['X-WP-Nonce'] = config.nonce;
        headers['Accept'] = 'application/json';
        if (options.body && !(options.body instanceof FormData)) {
            headers['Content-Type'] = 'application/json';
            options.body = JSON.stringify(options.body);
        }
        return fetch(config.restUrl + path.replace(/^\//, ''), Object.assign({}, options, { headers: headers, credentials: 'same-origin' }))
            .then(function (response) {
                return response.json().then(function (json) {
                    if (!response.ok) {
                        throw new Error(json && json.message ? json.message : __('Request failed.', 'aiseo-content-studio'));
                    }
                    return json;
                });
            });
    }

    function field(label, value, onChange, type, props) {
        props = props || {};
        return h('label', { className: 'aiseocs-field' },
            h('span', null, label),
            h('input', Object.assign({
                type: type || 'text',
                value: value === undefined || value === null ? '' : value,
                onChange: function (event) { onChange(event.target.value); }
            }, props))
        );
    }

    function textarea(label, value, onChange, props) {
        props = props || {};
        return h('label', { className: 'aiseocs-field aiseocs-field-wide' },
            h('span', null, label),
            h('textarea', Object.assign({
                value: value || '',
                rows: props.rows || 5,
                onChange: function (event) { onChange(event.target.value); }
            }, props))
        );
    }

    function select(label, value, onChange, options) {
        return h('label', { className: 'aiseocs-field' },
            h('span', null, label),
            h('select', { value: value || '', onChange: function (event) { onChange(event.target.value); } },
                options.map(function (option) {
                    return h('option', { key: option.value, value: option.value }, option.label);
                })
            )
        );
    }

    function button(label, onClick, variant, disabled) {
        return h('button', {
            type: 'button',
            className: 'aiseocs-button ' + (variant || ''),
            onClick: onClick,
            disabled: !!disabled
        }, label);
    }

    function Notice(props) {
        if (!props.message) {
            return null;
        }
        return h('div', { className: 'aiseocs-notice ' + (props.type || 'info') }, props.message);
    }

    function Providers(props) {
        var empty = {
            name: '', slug: '', type: 'custom', base_url: '', endpoint_path: '/chat/completions', image_endpoint_path: '', api_key: '', default_model: '', models: '', is_active: true, is_default: false
        };
        var form = props.providerForm;
        var set = function (key, value) { props.setProviderForm(Object.assign({}, form, (function () { var item = {}; item[key] = value; return item; }()))); };

        return h('div', { className: 'aiseocs-grid' },
            h('div', { className: 'aiseocs-card aiseocs-span-5' },
                h('h2', null, __('AI Providers', 'aiseo-content-studio')),
                h('p', null, __('Add unlimited providers. Built-in providers support OpenAI, Gemini, Claude, DeepSeek, OpenRouter, Groq, and Ollama.', 'aiseo-content-studio')),
                h('div', { className: 'aiseocs-provider-list' },
                    props.providers.map(function (provider) {
                        return h('div', { className: 'aiseocs-provider-row', key: provider.id },
                            h('div', null,
                                h('strong', null, provider.name),
                                h('span', null, provider.slug + ' · ' + provider.type + ' · ' + (provider.default_model || __('No model', 'aiseo-content-studio'))),
                                h('em', null, provider.has_api_key ? __('API key saved', 'aiseo-content-studio') : (provider.type === 'ollama' ? __('Local provider', 'aiseo-content-studio') : __('API key missing', 'aiseo-content-studio')))
                            ),
                            h('div', { className: 'aiseocs-row-actions' },
                                provider.is_default ? h('span', { className: 'aiseocs-badge' }, __('Default', 'aiseo-content-studio')) : null,
                                button(__('Edit', 'aiseo-content-studio'), function () {
                                    props.setProviderForm(Object.assign({}, provider, { api_key: '', models: (provider.models || []).join('\n') }));
                                }, 'secondary'),
                                button(__('Delete', 'aiseo-content-studio'), function () { props.deleteProvider(provider.id); }, 'danger')
                            )
                        );
                    })
                )
            ),
            h('div', { className: 'aiseocs-card aiseocs-span-7' },
                h('h2', null, form.id ? __('Edit Provider', 'aiseo-content-studio') : __('Add Provider', 'aiseo-content-studio')),
                h('div', { className: 'aiseocs-form-grid' },
                    field(__('Name', 'aiseo-content-studio'), form.name, function (v) { set('name', v); }),
                    field(__('Slug', 'aiseo-content-studio'), form.slug, function (v) { set('slug', v); }),
                    select(__('Type', 'aiseo-content-studio'), form.type, function (v) { set('type', v); }, [
                        { value: 'openai', label: 'OpenAI' }, { value: 'gemini', label: 'Gemini' }, { value: 'claude', label: 'Claude' }, { value: 'deepseek', label: 'DeepSeek' }, { value: 'openrouter', label: 'OpenRouter' }, { value: 'groq', label: 'Groq' }, { value: 'ollama', label: 'Ollama' }, { value: 'custom', label: __('Custom OpenAI-compatible', 'aiseo-content-studio') }
                    ]),
                    field(__('Base URL', 'aiseo-content-studio'), form.base_url, function (v) { set('base_url', v); }),
                    field(__('Chat Endpoint', 'aiseo-content-studio'), form.endpoint_path, function (v) { set('endpoint_path', v); }),
                    field(__('Image Endpoint', 'aiseo-content-studio'), form.image_endpoint_path, function (v) { set('image_endpoint_path', v); }),
                    field(__('Default Model', 'aiseo-content-studio'), form.default_model, function (v) { set('default_model', v); }),
                    field(__('API Key', 'aiseo-content-studio'), form.api_key || '', function (v) { set('api_key', v); }, 'password', { autoComplete: 'new-password', placeholder: form.has_api_key ? __('Leave empty to keep saved key', 'aiseo-content-studio') : '' }),
                    textarea(__('Models, one per line', 'aiseo-content-studio'), form.models, function (v) { set('models', v); }, { rows: 4 })
                ),
                h('label', { className: 'aiseocs-check' }, h('input', { type: 'checkbox', checked: !!form.is_active, onChange: function (e) { set('is_active', e.target.checked); } }), __('Active', 'aiseo-content-studio')),
                h('label', { className: 'aiseocs-check' }, h('input', { type: 'checkbox', checked: !!form.is_default, onChange: function (e) { set('is_default', e.target.checked); } }), __('Default provider', 'aiseo-content-studio')),
                h('div', { className: 'aiseocs-actions' },
                    button(form.id ? __('Save Provider', 'aiseo-content-studio') : __('Add Provider', 'aiseo-content-studio'), props.saveProvider, 'primary', props.loading),
                    button(__('Reset', 'aiseo-content-studio'), function () { props.setProviderForm(empty); }, 'secondary')
                )
            )
        );
    }

    function Settings(props) {
        var s = props.settings || {};
        var set = function (key, value) { props.setSettings(Object.assign({}, s, (function () { var item = {}; item[key] = value; return item; }()))); };
        return h('div', { className: 'aiseocs-card' },
            h('h2', null, __('Settings', 'aiseo-content-studio')),
            h('div', { className: 'aiseocs-form-grid' },
                select(__('Default Provider', 'aiseo-content-studio'), s.default_provider, function (v) { set('default_provider', v); }, props.providers.map(function (p) { return { value: p.slug, label: p.name }; })),
                field(__('Default Model', 'aiseo-content-studio'), s.default_model, function (v) { set('default_model', v); }),
                select(__('Language', 'aiseo-content-studio'), s.language, function (v) { set('language', v); }, [{ value: 'fa_IR', label: 'فارسی' }, { value: 'en_US', label: 'English' }]),
                select(__('Tone', 'aiseo-content-studio'), s.tone, function (v) { set('tone', v); }, toneOptions()),
                select(__('Writing Style', 'aiseo-content-studio'), s.writing_style, function (v) { set('writing_style', v); }, styleOptions()),
                select(__('Length', 'aiseo-content-studio'), s.length, function (v) { set('length', v); }, lengthOptions()),
                field(__('Temperature', 'aiseo-content-studio'), s.temperature, function (v) { set('temperature', v); }, 'number', { step: '0.1', min: '0', max: '2' }),
                field(__('Top P', 'aiseo-content-studio'), s.top_p, function (v) { set('top_p', v); }, 'number', { step: '0.05', min: '0', max: '1' }),
                field(__('Presence Penalty', 'aiseo-content-studio'), s.presence_penalty, function (v) { set('presence_penalty', v); }, 'number', { step: '0.1', min: '-2', max: '2' }),
                field(__('Frequency Penalty', 'aiseo-content-studio'), s.frequency_penalty, function (v) { set('frequency_penalty', v); }, 'number', { step: '0.1', min: '-2', max: '2' }),
                field(__('Max Tokens', 'aiseo-content-studio'), s.max_tokens, function (v) { set('max_tokens', v); }, 'number'),
                field(__('Cache TTL Seconds', 'aiseo-content-studio'), s.cache_ttl, function (v) { set('cache_ttl', v); }, 'number'),
                field(__('History Retention Days', 'aiseo-content-studio'), s.history_retention_days, function (v) { set('history_retention_days', v); }, 'number'),
                select(__('Theme', 'aiseo-content-studio'), s.theme, function (v) { set('theme', v); }, [{ value: 'auto', label: __('Auto', 'aiseo-content-studio') }, { value: 'light', label: __('Light', 'aiseo-content-studio') }, { value: 'dark', label: __('Dark', 'aiseo-content-studio') }])
            ),
            h('div', { className: 'aiseocs-check-grid' },
                check(__('Cache repeated prompts', 'aiseo-content-studio'), s.cache_enabled, function (v) { set('cache_enabled', v); }),
                check(__('Auto-fill SEO plugins', 'aiseo-content-studio'), s.auto_fill_seo_plugins, function (v) { set('auto_fill_seo_plugins', v); }),
                check(__('Use Persian-friendly fonts in RTL', 'aiseo-content-studio'), s.rtl_fonts, function (v) { set('rtl_fonts', v); }),
                check(__('Delete plugin data on uninstall', 'aiseo-content-studio'), s.delete_data_on_uninstall, function (v) { set('delete_data_on_uninstall', v); })
            ),
            h('div', { className: 'aiseocs-actions' }, button(__('Save Settings', 'aiseo-content-studio'), props.saveSettings, 'primary', props.loading))
        );
    }

    function check(label, checked, onChange) {
        return h('label', { className: 'aiseocs-check' }, h('input', { type: 'checkbox', checked: !!checked, onChange: function (e) { onChange(e.target.checked); } }), label);
    }

    function Generator(props) {
        var f = props.generateForm;
        var set = function (key, value) { props.setGenerateForm(Object.assign({}, f, (function () { var item = {}; item[key] = value; return item; }()))); };
        return h('div', { className: 'aiseocs-grid' },
            h('div', { className: 'aiseocs-card aiseocs-span-5' },
                h('h2', null, __('Content Generator', 'aiseo-content-studio')),
                select(__('Feature', 'aiseo-content-studio'), f.feature, function (v) { set('feature', v); }, featureOptions()),
                select(__('Provider', 'aiseo-content-studio'), f.provider, function (v) { set('provider', v); }, [{ value: '', label: __('Default', 'aiseo-content-studio') }].concat(props.providers.map(function (p) { return { value: p.slug, label: p.name }; }))),
                field(__('Model', 'aiseo-content-studio'), f.model, function (v) { set('model', v); }),
                select(__('Language', 'aiseo-content-studio'), f.language, function (v) { set('language', v); }, [{ value: 'fa_IR', label: 'فارسی' }, { value: 'en_US', label: 'English' }]),
                select(__('Tone', 'aiseo-content-studio'), f.tone, function (v) { set('tone', v); }, toneOptions()),
                select(__('Writing Style', 'aiseo-content-studio'), f.writing_style, function (v) { set('writing_style', v); }, styleOptions()),
                select(__('Length', 'aiseo-content-studio'), f.length, function (v) { set('length', v); }, lengthOptions()),
                field(__('Temperature', 'aiseo-content-studio'), f.temperature, function (v) { set('temperature', v); }, 'number', { step: '0.1', min: '0', max: '2' }),
                field(__('Top P', 'aiseo-content-studio'), f.top_p, function (v) { set('top_p', v); }, 'number', { step: '0.05', min: '0', max: '1' }),
                field(__('Presence Penalty', 'aiseo-content-studio'), f.presence_penalty, function (v) { set('presence_penalty', v); }, 'number', { step: '0.1', min: '-2', max: '2' }),
                field(__('Frequency Penalty', 'aiseo-content-studio'), f.frequency_penalty, function (v) { set('frequency_penalty', v); }, 'number', { step: '0.1', min: '-2', max: '2' }),
                textarea(__('Topic, brief, or source text', 'aiseo-content-studio'), f.topic, function (v) { set('topic', v); }, { rows: 8 }),
                field(__('SEO Keywords', 'aiseo-content-studio'), f.keywords, function (v) { set('keywords', v); }),
                h('div', { className: 'aiseocs-actions' }, button(__('Generate', 'aiseo-content-studio'), props.generate, 'primary', props.loading))
            ),
            h('div', { className: 'aiseocs-card aiseocs-span-7' },
                h('h2', null, __('Output', 'aiseo-content-studio')),
                props.generation ? h('div', { className: 'aiseocs-output-meta' },
                    h('span', null, __('Provider:', 'aiseo-content-studio') + ' ' + props.generation.provider),
                    h('span', null, __('Model:', 'aiseo-content-studio') + ' ' + props.generation.model),
                    h('span', null, __('Tokens:', 'aiseo-content-studio') + ' ' + (props.generation.usage ? props.generation.usage.total_tokens : 0)),
                    h('span', null, __('Cost:', 'aiseo-content-studio') + ' $' + (props.generation.cost || 0))
                ) : null,
                h('textarea', { className: 'aiseocs-output', value: props.generation ? props.generation.content : '', readOnly: true, rows: 22 }),
                props.generation ? h('div', { className: 'aiseocs-actions' },
                    button(__('Copy', 'aiseo-content-studio'), function () { navigator.clipboard.writeText(props.generation.content || ''); }, 'secondary'),
                    button(__('Export TXT', 'aiseo-content-studio'), function () { downloadFile('aiseocs-output.txt', 'text/plain;charset=utf-8', props.generation.content || ''); }, 'secondary')
                ) : null
            )
        );
    }

    function Prompts(props) {
        var p = props.promptForm;
        var set = function (key, value) { props.setPromptForm(Object.assign({}, p, (function () { var item = {}; item[key] = value; return item; }()))); };
        return h('div', { className: 'aiseocs-grid' },
            h('div', { className: 'aiseocs-card aiseocs-span-5' },
                h('h2', null, __('Prompt Library', 'aiseo-content-studio')),
                props.prompts.map(function (prompt) {
                    return h('div', { className: 'aiseocs-prompt-row', key: prompt.id },
                        h('strong', null, prompt.title),
                        h('span', null, prompt.category + (prompt.is_favorite ? ' ★' : '')),
                        h('p', null, prompt.content),
                        h('div', { className: 'aiseocs-row-actions' },
                            button(__('Use', 'aiseo-content-studio'), function () { props.usePrompt(prompt); }, 'secondary'),
                            button(__('Edit', 'aiseo-content-studio'), function () { props.setPromptForm(prompt); }, 'secondary'),
                            button(__('Delete', 'aiseo-content-studio'), function () { props.deletePrompt(prompt.id); }, 'danger')
                        )
                    );
                })
            ),
            h('div', { className: 'aiseocs-card aiseocs-span-7' },
                h('h2', null, p.id ? __('Edit Prompt', 'aiseo-content-studio') : __('Save Prompt', 'aiseo-content-studio')),
                field(__('Title', 'aiseo-content-studio'), p.title, function (v) { set('title', v); }),
                field(__('Category', 'aiseo-content-studio'), p.category, function (v) { set('category', v); }),
                field(__('Language', 'aiseo-content-studio'), p.language, function (v) { set('language', v); }),
                textarea(__('Prompt', 'aiseo-content-studio'), p.content, function (v) { set('content', v); }, { rows: 12 }),
                check(__('Favorite', 'aiseo-content-studio'), p.is_favorite, function (v) { set('is_favorite', v); }),
                h('div', { className: 'aiseocs-actions' },
                    button(p.id ? __('Save Prompt', 'aiseo-content-studio') : __('Create Prompt', 'aiseo-content-studio'), props.savePrompt, 'primary', props.loading),
                    button(__('Export Prompts', 'aiseo-content-studio'), function () { props.exportData('prompts', 'json'); }, 'secondary')
                )
            )
        );
    }

    function History(props) {
        return h('div', { className: 'aiseocs-card' },
            h('h2', null, __('Content History', 'aiseo-content-studio')),
            h('div', { className: 'aiseocs-actions' },
                button(__('Refresh', 'aiseo-content-studio'), props.loadHistory, 'secondary'),
                button(__('Export JSON', 'aiseo-content-studio'), function () { props.exportData('history', 'json'); }, 'secondary'),
                button(__('Export CSV', 'aiseo-content-studio'), function () { props.exportData('history', 'csv'); }, 'secondary'),
                button(__('Export TXT', 'aiseo-content-studio'), function () { props.exportData('history', 'txt'); }, 'secondary'),
                button(__('Export PDF', 'aiseo-content-studio'), function () { props.exportData('history', 'pdf'); }, 'secondary')
            ),
            h('div', { className: 'aiseocs-table-wrap' },
                h('table', { className: 'widefat striped aiseocs-table' },
                    h('thead', null, h('tr', null, h('th', null, 'ID'), h('th', null, __('Feature', 'aiseo-content-studio')), h('th', null, __('Object', 'aiseo-content-studio')), h('th', null, __('Provider', 'aiseo-content-studio')), h('th', null, __('Created', 'aiseo-content-studio')), h('th', null, __('Actions', 'aiseo-content-studio')))),
                    h('tbody', null, props.history.map(function (row) {
                        return h('tr', { key: row.id },
                            h('td', null, row.id), h('td', null, row.feature), h('td', null, row.object_type + ' #' + row.object_id), h('td', null, row.provider + ' / ' + row.model), h('td', null, row.created_at),
                            h('td', null, button(__('Restore', 'aiseo-content-studio'), function () { props.restoreHistory(row.id); }, 'secondary'))
                        );
                    }))
                )
            )
        );
    }

    function Bulk(props) {
        var b = props.bulkForm;
        var set = function (key, value) { props.setBulkForm(Object.assign({}, b, (function () { var item = {}; item[key] = value; return item; }()))); };
        return h('div', { className: 'aiseocs-grid' },
            h('div', { className: 'aiseocs-card aiseocs-span-4' },
                h('h2', null, __('Bulk Generator', 'aiseo-content-studio')),
                textarea(__('Product IDs', 'aiseo-content-studio'), b.product_ids, function (v) { set('product_ids', v); }, { rows: 6, placeholder: '12, 15, 22' }),
                select(__('Action', 'aiseo-content-studio'), b.action, function (v) { set('action', v); }, productFeatureOptions()),
                select(__('Language', 'aiseo-content-studio'), b.language, function (v) { set('language', v); }, [{ value: 'fa_IR', label: 'فارسی' }, { value: 'en_US', label: 'English' }]),
                check(__('Apply automatically after generation', 'aiseo-content-studio'), b.apply, function (v) { set('apply', v); }),
                h('div', { className: 'aiseocs-actions' },
                    button(__('Add to Queue', 'aiseo-content-studio'), props.enqueueBulk, 'primary', props.loading),
                    button(__('Process Now', 'aiseo-content-studio'), props.processQueue, 'secondary', props.loading)
                )
            ),
            h('div', { className: 'aiseocs-card aiseocs-span-8' },
                h('h2', null, __('Queue', 'aiseo-content-studio')),
                h('div', { className: 'aiseocs-actions' }, button(__('Refresh', 'aiseo-content-studio'), props.loadQueue, 'secondary')),
                h('div', { className: 'aiseocs-table-wrap' },
                    h('table', { className: 'widefat striped aiseocs-table' },
                        h('thead', null, h('tr', null, h('th', null, 'ID'), h('th', null, __('Product', 'aiseo-content-studio')), h('th', null, __('Action', 'aiseo-content-studio')), h('th', null, __('Status', 'aiseo-content-studio')), h('th', null, __('Attempts', 'aiseo-content-studio')))),
                        h('tbody', null, props.queue.map(function (job) {
                            return h('tr', { key: job.id }, h('td', null, job.id), h('td', null, job.object_id), h('td', null, job.action), h('td', null, job.status), h('td', null, job.attempts + '/' + job.max_attempts));
                        }))
                    )
                ),
                h('h2', null, __('Request Logs', 'aiseo-content-studio')),
                props.logs.slice(0, 10).map(function (log) {
                    return h('div', { className: 'aiseocs-log-row', key: log.id }, log.created_at + ' · ' + log.provider + ' · ' + log.status + ' · ' + log.total_tokens + ' tokens · $' + log.estimated_cost);
                })
            )
        );
    }

    function Chat(props) {
        return h('div', { className: 'aiseocs-card aiseocs-chat-card' },
            h('h2', null, __('AI Chat', 'aiseo-content-studio')),
            h('div', { className: 'aiseocs-chat-window' },
                props.chatMessages.map(function (message, index) {
                    return h('div', { className: 'aiseocs-chat-message ' + message.role, key: index },
                        h('strong', null, message.role === 'user' ? __('You', 'aiseo-content-studio') : __('AI', 'aiseo-content-studio')),
                        h('p', null, message.content)
                    );
                })
            ),
            h('div', { className: 'aiseocs-chat-input' },
                h('textarea', { rows: 4, value: props.chatInput, onChange: function (e) { props.setChatInput(e.target.value); }, placeholder: __('Ask about content, products, SEO, or rewrite selected text…', 'aiseo-content-studio') }),
                button(__('Send', 'aiseo-content-studio'), props.sendChat, 'primary', props.loading)
            )
        );
    }

    function featureOptions() {
        return [
            ['blog_post', __('Blog Post', 'aiseo-content-studio')], ['page', __('Page', 'aiseo-content-studio')], ['category', __('Category', 'aiseo-content-studio')], ['tag', __('Tag', 'aiseo-content-studio')], ['seo_content', __('SEO Content', 'aiseo-content-studio')], ['faq', __('FAQ', 'aiseo-content-studio')], ['how_to', __('How-To', 'aiseo-content-studio')], ['product_review', __('Product Review', 'aiseo-content-studio')], ['comparison_article', __('Comparison Article', 'aiseo-content-studio')], ['news', __('News', 'aiseo-content-studio')], ['landing_page', __('Landing Page', 'aiseo-content-studio')], ['rewrite', __('Rewrite', 'aiseo-content-studio')], ['summarize', __('Summarize', 'aiseo-content-studio')], ['expand', __('Expand', 'aiseo-content-studio')], ['shorten', __('Shorten', 'aiseo-content-studio')], ['translate', __('Translate', 'aiseo-content-studio')], ['grammar', __('Improve Grammar', 'aiseo-content-studio')], ['humanize', __('Humanize AI Text', 'aiseo-content-studio')], ['remove_ai_tone', __('Remove AI Tone', 'aiseo-content-studio')]
        ].map(function (item) { return { value: item[0], label: item[1] }; });
    }

    function productFeatureOptions() {
        return [
            ['product_bundle', __('Complete Product Package', 'aiseo-content-studio')], ['rewrite_product', __('Bulk Rewrite Product Content', 'aiseo-content-studio')], ['seo_description', __('SEO Product Description', 'aiseo-content-studio')], ['short_description', __('Short Description', 'aiseo-content-studio')], ['seo_title', __('SEO Title', 'aiseo-content-studio')], ['meta_description', __('Meta Description', 'aiseo-content-studio')], ['focus_keywords', __('Focus Keywords', 'aiseo-content-studio')], ['image_alt', __('ALT Text', 'aiseo-content-studio')], ['product_tags', __('Product Tags', 'aiseo-content-studio')], ['seo_score', __('SEO Score', 'aiseo-content-studio')]
        ].map(function (item) { return { value: item[0], label: item[1] }; });
    }

    function toneOptions() {
        return [
            { value: 'professional', label: __('Professional', 'aiseo-content-studio') }, { value: 'friendly', label: __('Friendly', 'aiseo-content-studio') }, { value: 'luxury', label: __('Luxury', 'aiseo-content-studio') }, { value: 'persuasive', label: __('Persuasive', 'aiseo-content-studio') }, { value: 'educational', label: __('Educational', 'aiseo-content-studio') }, { value: 'conversational', label: __('Conversational', 'aiseo-content-studio') }
        ];
    }

    function styleOptions() {
        return [
            { value: 'seo_editorial', label: __('SEO Editorial', 'aiseo-content-studio') }, { value: 'woocommerce_sales', label: __('WooCommerce Sales', 'aiseo-content-studio') }, { value: 'storytelling', label: __('Storytelling', 'aiseo-content-studio') }, { value: 'technical', label: __('Technical', 'aiseo-content-studio') }
        ];
    }

    function lengthOptions() {
        return [
            { value: 'short', label: __('Short', 'aiseo-content-studio') }, { value: 'medium', label: __('Medium', 'aiseo-content-studio') }, { value: 'long', label: __('Long', 'aiseo-content-studio') }, { value: 'very_long', label: __('Very Long', 'aiseo-content-studio') }
        ];
    }

    function downloadFile(filename, type, body, isBase64) {
        var data = isBase64 ? Uint8Array.from(atob(body), function (c) { return c.charCodeAt(0); }) : body;
        var blob = new Blob([data], { type: type });
        var url = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        a.remove();
        URL.revokeObjectURL(url);
    }

    function App() {
        var tabs = ['generator', 'providers', 'prompts', 'history', 'bulk', 'chat', 'settings'];
        var tabLabels = { generator: __('Generator', 'aiseo-content-studio'), providers: __('Providers', 'aiseo-content-studio'), prompts: __('Prompts', 'aiseo-content-studio'), history: __('History', 'aiseo-content-studio'), bulk: __('Bulk', 'aiseo-content-studio'), chat: __('Chat', 'aiseo-content-studio'), settings: __('Settings', 'aiseo-content-studio') };
        var savedTheme = window.localStorage.getItem('aiseocs-theme') || 'auto';
        var initialGenerate = { feature: 'blog_post', provider: '', model: '', language: config.locale.indexOf('fa') === 0 ? 'fa_IR' : 'en_US', tone: 'professional', writing_style: 'seo_editorial', length: 'long', temperature: 0.7, top_p: 1, presence_penalty: 0, frequency_penalty: 0, topic: '', keywords: '' };
        var initialProvider = { name: '', slug: '', type: 'custom', base_url: '', endpoint_path: '/chat/completions', image_endpoint_path: '', api_key: '', default_model: '', models: '', is_active: true, is_default: false };
        var initialPrompt = { title: '', category: 'general', language: config.locale, content: '', is_favorite: false };

        var stateTab = useState(tabs.indexOf(config.initialTab) !== -1 ? config.initialTab : 'generator');
        var activeTab = stateTab[0];
        var setActiveTab = stateTab[1];
        var settingsState = useState({});
        var settings = settingsState[0];
        var setSettings = settingsState[1];
        var providersState = useState([]);
        var providers = providersState[0];
        var setProviders = providersState[1];
        var loadingState = useState(false);
        var loading = loadingState[0];
        var setLoading = loadingState[1];
        var noticeState = useState({ message: '', type: 'info' });
        var notice = noticeState[0];
        var setNotice = noticeState[1];
        var providerFormState = useState(initialProvider);
        var providerForm = providerFormState[0];
        var setProviderForm = providerFormState[1];
        var generateFormState = useState(initialGenerate);
        var generateForm = generateFormState[0];
        var setGenerateForm = generateFormState[1];
        var generationState = useState(null);
        var generation = generationState[0];
        var setGeneration = generationState[1];
        var promptsState = useState([]);
        var prompts = promptsState[0];
        var setPrompts = promptsState[1];
        var promptFormState = useState(initialPrompt);
        var promptForm = promptFormState[0];
        var setPromptForm = promptFormState[1];
        var historyState = useState([]);
        var history = historyState[0];
        var setHistory = historyState[1];
        var queueState = useState([]);
        var queue = queueState[0];
        var setQueue = queueState[1];
        var logsState = useState([]);
        var logs = logsState[0];
        var setLogs = logsState[1];
        var bulkState = useState({ product_ids: '', action: 'product_bundle', language: initialGenerate.language, apply: false });
        var bulkForm = bulkState[0];
        var setBulkForm = bulkState[1];
        var chatState = useState([{ role: 'assistant', content: __('Hello. Ask me to write, rewrite, summarize, translate, or improve WooCommerce product content.', 'aiseo-content-studio') }]);
        var chatMessages = chatState[0];
        var setChatMessages = chatState[1];
        var chatInputState = useState('');
        var chatInput = chatInputState[0];
        var setChatInput = chatInputState[1];
        var themeState = useState(savedTheme);
        var theme = themeState[0];
        var setTheme = themeState[1];

        function report(promise, success) {
            setLoading(true);
            setNotice({ message: '', type: 'info' });
            return promise.then(function (data) {
                if (success) {
                    setNotice({ message: success, type: 'success' });
                }
                return data;
            }).catch(function (error) {
                setNotice({ message: error.message, type: 'error' });
            }).finally(function () { setLoading(false); });
        }

        function loadSettings() {
            return api('settings').then(function (data) {
                setSettings(data.settings || {});
                setProviders(data.providers || []);
                if (data.settings) {
                    setGenerateForm(Object.assign({}, initialGenerate, { provider: data.settings.default_provider || '', model: data.settings.default_model || '', language: data.settings.language || initialGenerate.language, tone: data.settings.tone || 'professional', writing_style: data.settings.writing_style || 'seo_editorial', length: data.settings.length || 'long', temperature: data.settings.temperature, top_p: data.settings.top_p, presence_penalty: data.settings.presence_penalty, frequency_penalty: data.settings.frequency_penalty }));
                    setTheme(data.settings.theme || savedTheme);
                }
            });
        }

        function loadPrompts() { return api('prompts').then(function (data) { setPrompts(data.prompts || []); }); }
        function loadHistory() { return api('history?limit=50').then(function (data) { setHistory(data.history || []); }); }
        function loadQueue() { return api('queue?limit=50').then(function (data) { setQueue(data.queue || []); }).then(function () { return api('logs?limit=20').then(function (data) { setLogs(data.logs || []); }); }); }

        useEffect(function () {
            report(Promise.all([loadSettings(), loadPrompts(), loadHistory(), loadQueue()]));
        }, []);

        useEffect(function () {
            root.classList.toggle('aiseocs-dark', theme === 'dark' || (theme === 'auto' && window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches));
            window.localStorage.setItem('aiseocs-theme', theme);
        }, [theme]);

        function saveSettings() {
            var merged = Object.assign({}, settings, { theme: theme });
            report(api('settings', { method: 'POST', body: merged }).then(function (data) { setSettings(data.settings || merged); return loadSettings(); }), __('Settings saved.', 'aiseo-content-studio'));
        }

        function saveProvider() {
            var data = Object.assign({}, providerForm);
            if (typeof data.models === 'string') {
                data.models = data.models.split(/\n|,/).map(function (v) { return v.trim(); }).filter(Boolean);
            }
            var method = data.id ? 'PUT' : 'POST';
            var path = data.id ? 'providers/' + data.id : 'providers';
            report(api(path, { method: method, body: data }).then(function () { setProviderForm(initialProvider); return loadSettings(); }), __('Provider saved.', 'aiseo-content-studio'));
        }

        function deleteProvider(id) {
            if (!window.confirm(__('Delete this provider?', 'aiseo-content-studio'))) { return; }
            report(api('providers/' + id, { method: 'DELETE' }).then(loadSettings), __('Provider deleted.', 'aiseo-content-studio'));
        }

        function generate() {
            report(api('generate', { method: 'POST', body: generateForm }).then(function (data) { setGeneration(data); }), __('Content generated.', 'aiseo-content-studio'));
        }

        function savePrompt() {
            var method = promptForm.id ? 'PUT' : 'POST';
            var path = promptForm.id ? 'prompts/' + promptForm.id : 'prompts';
            report(api(path, { method: method, body: promptForm }).then(function () { setPromptForm(initialPrompt); return loadPrompts(); }), __('Prompt saved.', 'aiseo-content-studio'));
        }

        function deletePrompt(id) {
            if (!window.confirm(__('Delete this prompt?', 'aiseo-content-studio'))) { return; }
            report(api('prompts/' + id, { method: 'DELETE' }).then(loadPrompts), __('Prompt deleted.', 'aiseo-content-studio'));
        }

        function usePrompt(prompt) {
            setGenerateForm(Object.assign({}, generateForm, { topic: prompt.content }));
            setActiveTab('generator');
        }

        function restoreHistory(id) {
            if (!window.confirm(__('Restore this version?', 'aiseo-content-studio'))) { return; }
            report(api('history/' + id, { method: 'POST' }).then(loadHistory), __('History restored.', 'aiseo-content-studio'));
        }

        function exportData(type, format) {
            report(api('export/' + type + '?format=' + encodeURIComponent(format)).then(function (data) {
                downloadFile(data.filename, data.content_type, data.body, data.base64);
            }), __('Export ready.', 'aiseo-content-studio'));
        }

        function enqueueBulk() {
            report(api('queue/enqueue', { method: 'POST', body: { product_ids: bulkForm.product_ids, actions: [bulkForm.action], language: bulkForm.language, apply: bulkForm.apply } }).then(loadQueue), __('Bulk jobs added to the queue.', 'aiseo-content-studio'));
        }

        function processQueue() {
            report(api('queue/process', { method: 'POST', body: { limit: 3 } }).then(loadQueue), __('Queue processed.', 'aiseo-content-studio'));
        }

        function sendChat() {
            var text = chatInput.trim();
            if (!text) { return; }
            var next = chatMessages.concat([{ role: 'user', content: text }]);
            setChatMessages(next);
            setChatInput('');
            report(api('chat', { method: 'POST', body: { messages: next.filter(function (m) { return m.role !== 'assistant' || m.content.indexOf('Hello.') !== 0; }) } }).then(function (data) {
                setChatMessages(next.concat([{ role: 'assistant', content: data.content || '' }]));
            }));
        }

        return h('div', { className: 'aiseocs-shell ' + (config.isRtl ? 'rtl' : 'ltr') },
            h('header', { className: 'aiseocs-hero' },
                h('div', null,
                    h('p', { className: 'aiseocs-kicker' }, __('Premium WordPress & WooCommerce AI Workspace', 'aiseo-content-studio')),
                    h('h1', null, __('AI SEO Content Studio', 'aiseo-content-studio')),
                    h('p', null, __('Generate SEO content, product copy, metadata, schemas, images, prompts, and bulk jobs with secure provider control.', 'aiseo-content-studio'))
                ),
                h('div', { className: 'aiseocs-hero-actions' },
                    select(__('Theme', 'aiseo-content-studio'), theme, setTheme, [{ value: 'auto', label: __('Auto', 'aiseo-content-studio') }, { value: 'light', label: __('Light', 'aiseo-content-studio') }, { value: 'dark', label: __('Dark', 'aiseo-content-studio') }])
                )
            ),
            h(Notice, notice),
            loading ? h('div', { className: 'aiseocs-loading' }, __('Working…', 'aiseo-content-studio')) : null,
            h('nav', { className: 'aiseocs-tabs' }, tabs.map(function (tab) { return h('button', { type: 'button', key: tab, className: activeTab === tab ? 'active' : '', onClick: function () { setActiveTab(tab); } }, tabLabels[tab]); })),
            activeTab === 'generator' ? h(Generator, { providers: providers, generateForm: generateForm, setGenerateForm: setGenerateForm, generation: generation, generate: generate, loading: loading }) : null,
            activeTab === 'providers' ? h(Providers, { providers: providers, providerForm: providerForm, setProviderForm: setProviderForm, saveProvider: saveProvider, deleteProvider: deleteProvider, loading: loading }) : null,
            activeTab === 'prompts' ? h(Prompts, { prompts: prompts, promptForm: promptForm, setPromptForm: setPromptForm, savePrompt: savePrompt, deletePrompt: deletePrompt, usePrompt: usePrompt, exportData: exportData, loading: loading }) : null,
            activeTab === 'history' ? h(History, { history: history, loadHistory: loadHistory, restoreHistory: restoreHistory, exportData: exportData }) : null,
            activeTab === 'bulk' ? h(Bulk, { bulkForm: bulkForm, setBulkForm: setBulkForm, queue: queue, logs: logs, enqueueBulk: enqueueBulk, processQueue: processQueue, loadQueue: loadQueue, loading: loading }) : null,
            activeTab === 'chat' ? h(Chat, { chatMessages: chatMessages, chatInput: chatInput, setChatInput: setChatInput, sendChat: sendChat, loading: loading }) : null,
            activeTab === 'settings' ? h(Settings, { settings: settings, setSettings: setSettings, providers: providers, saveSettings: saveSettings, loading: loading }) : null
        );
    }

    wp.element.render(h(App), root);
})(window.wp);
