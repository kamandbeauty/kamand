(function (wp) {
    'use strict';

    if (!wp || !wp.element) {
        return;
    }

    var h = wp.element.createElement;
    var useEffect = wp.element.useEffect;
    var useState = wp.element.useState;
    var __ = wp.i18n && wp.i18n.__ ? wp.i18n.__ : function (text) { return text; };
    var roots = document.querySelectorAll('.aiseocs-product-panel');

    function createApi(root) {
        var restUrl = root.getAttribute('data-rest-url');
        var nonce = root.getAttribute('data-nonce');
        return function api(path, options) {
            options = options || {};
            var headers = options.headers || {};
            headers['X-WP-Nonce'] = nonce;
            headers['Accept'] = 'application/json';
            if (options.body) {
                headers['Content-Type'] = 'application/json';
                options.body = JSON.stringify(options.body);
            }
            return fetch(restUrl + path.replace(/^\//, ''), Object.assign({}, options, { headers: headers, credentials: 'same-origin' }))
                .then(function (response) {
                    return response.json().then(function (json) {
                        if (!response.ok) {
                            throw new Error(json && json.message ? json.message : __('Request failed.', 'aiseo-content-studio'));
                        }
                        return json;
                    });
                });
        };
    }

    function button(label, onClick, variant, disabled) {
        return h('button', { type: 'button', className: 'aiseocs-panel-button ' + (variant || ''), onClick: onClick, disabled: !!disabled }, label);
    }

    function field(label, value, onChange, type) {
        return h('label', { className: 'aiseocs-panel-field' }, h('span', null, label), h('input', { type: type || 'text', value: value || '', onChange: function (event) { onChange(event.target.value); } }));
    }

    function select(label, value, onChange, options) {
        return h('label', { className: 'aiseocs-panel-field' },
            h('span', null, label),
            h('select', { value: value || '', onChange: function (event) { onChange(event.target.value); } }, options.map(function (option) { return h('option', { key: option.value, value: option.value }, option.label); }))
        );
    }

    function featureOptions() {
        return [
            ['seo_description', __('SEO Product Description', 'aiseo-content-studio')], ['rewrite_product', __('Rewrite Product Content', 'aiseo-content-studio')], ['short_description', __('Short Description', 'aiseo-content-studio')], ['seo_title', __('SEO Title', 'aiseo-content-studio')], ['meta_description', __('Meta Description', 'aiseo-content-studio')], ['focus_keywords', __('Focus Keywords', 'aiseo-content-studio')], ['product_slug', __('Product Slug', 'aiseo-content-studio')], ['product_excerpt', __('Product Excerpt', 'aiseo-content-studio')], ['benefits', __('Product Benefits', 'aiseo-content-studio')], ['features', __('Product Features', 'aiseo-content-studio')], ['specifications', __('Technical Specifications', 'aiseo-content-studio')], ['faq', __('Product FAQ', 'aiseo-content-studio')], ['pros_cons', __('Pros & Cons', 'aiseo-content-studio')], ['schema', __('Product Schema', 'aiseo-content-studio')], ['image_alt', __('ALT Text', 'aiseo-content-studio')], ['image_title', __('Image Title', 'aiseo-content-studio')], ['image_caption', __('Image Caption', 'aiseo-content-studio')], ['image_description', __('Image Description', 'aiseo-content-studio')], ['social_captions', __('Social Media Caption', 'aiseo-content-studio')], ['marketing_text', __('Marketing Text', 'aiseo-content-studio')], ['product_tags', __('Product Tags', 'aiseo-content-studio')], ['product_naming', __('AI Product Naming', 'aiseo-content-studio')], ['internal_links', __('Internal Linking', 'aiseo-content-studio')], ['related_products', __('Related Products', 'aiseo-content-studio')], ['seo_score', __('SEO Score', 'aiseo-content-studio')]
        ];
    }

    function payloadFromFeature(feature, result) {
        var content = result && result.content ? result.content.trim() : '';
        var parsed = result && result.parsed ? result.parsed : null;
        if (feature === 'product_bundle' && parsed) { return parsed; }
        if (feature === 'rewrite_product' && parsed) { return parsed; }
        if (feature === 'seo_description') { return { seo_description_html: content }; }
        if (feature === 'short_description') { return { short_description_html: content }; }
        if (feature === 'seo_title') { return { seo_title: content }; }
        if (feature === 'meta_description') { return { meta_description: content }; }
        if (feature === 'focus_keywords') { return { focus_keywords: parsed || content }; }
        if (feature === 'product_slug') { return { slug: content }; }
        if (feature === 'product_excerpt') { return { excerpt: content }; }
        if (feature === 'benefits') { return { benefits: lines(content) }; }
        if (feature === 'features') { return { features: lines(content) }; }
        if (feature === 'specifications') { return { specifications: parsed || content }; }
        if (feature === 'faq') { return { faq: parsed || content }; }
        if (feature === 'pros_cons') { return { pros: parsed && parsed.pros ? parsed.pros : lines(content), cons: parsed && parsed.cons ? parsed.cons : [] }; }
        if (feature === 'schema') { return { product_schema: parsed || content }; }
        if (feature.indexOf('image_') === 0) { return { image_seo: parsed || [] }; }
        if (feature === 'social_captions') { return { social_captions: parsed || content }; }
        if (feature === 'marketing_text') { return { marketing_text: parsed || content }; }
        if (feature === 'product_tags') { return { product_tags: parsed || lines(content) }; }
        if (feature === 'product_naming') { return { improved_titles: lines(content) }; }
        if (feature === 'internal_links') { return { internal_links: parsed || lines(content) }; }
        if (feature === 'related_products') { return { related_products: parsed || lines(content) }; }
        if (feature === 'seo_score') { return { seo_score: parsed || content }; }
        return { seo_description_html: content };
    }

    function lines(text) {
        return (text || '').split(/\n+/).map(function (line) { return line.replace(/^[-*\d.)\s]+/, '').trim(); }).filter(Boolean);
    }

    function preview(payload) {
        if (!payload) { return ''; }
        return typeof payload === 'string' ? payload : JSON.stringify(payload, null, 2);
    }

    function ContextSummary(props) {
        var context = props.context || {};
        var chips = [];
        if (context.title) { chips.push([__('Title', 'aiseo-content-studio'), context.title]); }
        if (context.sku) { chips.push([__('SKU', 'aiseo-content-studio'), context.sku]); }
        if (context.brand) { chips.push([__('Brand', 'aiseo-content-studio'), context.brand]); }
        if (context.price && context.price.current) { chips.push([__('Price', 'aiseo-content-studio'), context.price.current + ' ' + (context.price.currency || '')]); }
        if (context.category && context.category.length) { chips.push([__('Category', 'aiseo-content-studio'), context.category.join(', ')]); }
        if (context.tags && context.tags.length) { chips.push([__('Tags', 'aiseo-content-studio'), context.tags.join(', ')]); }
        if (context.images) { chips.push([__('Images', 'aiseo-content-studio'), String(context.images.length)]); }
        return h('div', { className: 'aiseocs-context' },
            chips.map(function (chip, index) { return h('span', { className: 'aiseocs-context-chip', key: index }, h('strong', null, chip[0] + ': '), chip[1]); })
        );
    }

    function ProductPanel(props) {
        var root = props.root;
        var api = props.api;
        var productId = root.getAttribute('data-product-id');
        var locale = root.getAttribute('data-locale') || 'en_US';
        var initialLanguage = locale.indexOf('fa') === 0 ? 'fa_IR' : 'en_US';
        var contextState = useState(null);
        var context = contextState[0];
        var setContext = contextState[1];
        var loadingState = useState(false);
        var loading = loadingState[0];
        var setLoading = loadingState[1];
        var noticeState = useState('');
        var notice = noticeState[0];
        var setNotice = noticeState[1];
        var errorState = useState('');
        var error = errorState[0];
        var setError = errorState[1];
        var languageState = useState(initialLanguage);
        var language = languageState[0];
        var setLanguage = languageState[1];
        var providerState = useState('');
        var provider = providerState[0];
        var setProvider = providerState[1];
        var modelState = useState('');
        var model = modelState[0];
        var setModel = modelState[1];
        var latestState = useState(null);
        var latest = latestState[0];
        var setLatest = latestState[1];
        var payloadState = useState(null);
        var payload = payloadState[0];
        var setPayload = payloadState[1];
        var imagePromptState = useState('');
        var imagePrompt = imagePromptState[0];
        var setImagePrompt = imagePromptState[1];

        function report(promise, success) {
            setLoading(true);
            setNotice('');
            setError('');
            return promise.then(function (data) {
                if (success) { setNotice(success); }
                return data;
            }).catch(function (err) { setError(err.message); }).finally(function () { setLoading(false); });
        }

        function loadContext() {
            return report(api('products/' + productId + '/context').then(function (data) { setContext(data.context); }), '');
        }

        useEffect(function () { loadContext(); }, []);

        function generate(feature) {
            report(api('products/' + productId + '/generate', { method: 'POST', body: { feature: feature, language: language, provider: provider, model: model } }).then(function (data) {
                var nextPayload = payloadFromFeature(feature, data);
                setLatest(data);
                setPayload(nextPayload);
            }), __('Generation complete.', 'aiseo-content-studio'));
        }

        function apply() {
            if (!payload) { setError(__('Generate content first.', 'aiseo-content-studio')); return; }
            report(api('products/' + productId + '/apply', { method: 'POST', body: { payload: payload } }).then(function () { return loadContext(); }), __('Content applied to product.', 'aiseo-content-studio'));
        }

        function generateImage() {
            report(api('products/' + productId + '/images/generate', { method: 'POST', body: { prompt: imagePrompt, provider: provider, model: model, set_featured: false } }).then(function (data) {
                setPayload({ generated_image: data });
            }), __('Image generated and saved to media library.', 'aiseo-content-studio'));
        }

        return h('div', { className: 'aiseocs-panel-shell' },
            h('div', { className: 'aiseocs-panel-hero' },
                h('div', null,
                    h('h2', null, __('WooCommerce Super AI', 'aiseo-content-studio')),
                    h('p', null, __('The assistant automatically detects product title, categories, tags, attributes, brand, price, custom fields, images, SKU, short description, and existing description.', 'aiseo-content-studio'))
                ),
                h('div', { className: 'aiseocs-panel-actions' },
                    button(__('Refresh Context', 'aiseo-content-studio'), loadContext, 'secondary', loading),
                    button(__('One-Click Full SEO Package', 'aiseo-content-studio'), function () { generate('product_bundle'); }, 'primary', loading)
                )
            ),
            notice ? h('div', { className: 'aiseocs-panel-notice success' }, notice) : null,
            error ? h('div', { className: 'aiseocs-panel-notice error' }, error) : null,
            loading ? h('div', { className: 'aiseocs-panel-loadingbar' }, __('Working with AI…', 'aiseo-content-studio')) : null,
            context ? h(ContextSummary, { context: context }) : h('p', null, __('Loading product context…', 'aiseo-content-studio')),
            h('div', { className: 'aiseocs-panel-controls' },
                select(__('Language', 'aiseo-content-studio'), language, setLanguage, [{ value: 'fa_IR', label: 'فارسی' }, { value: 'en_US', label: 'English' }]),
                field(__('Provider slug', 'aiseo-content-studio'), provider, setProvider),
                field(__('Model', 'aiseo-content-studio'), model, setModel)
            ),
            h('div', { className: 'aiseocs-feature-grid' },
                featureOptions().map(function (item) { return button(item[1], function () { generate(item[0]); }, item[0] === 'seo_description' ? 'accent' : 'secondary', loading); })
            ),
            h('div', { className: 'aiseocs-panel-grid' },
                h('div', { className: 'aiseocs-panel-card' },
                    h('h3', null, __('Generated Payload', 'aiseo-content-studio')),
                    latest ? h('div', { className: 'aiseocs-panel-meta' },
                        h('span', null, __('Provider:', 'aiseo-content-studio') + ' ' + latest.provider),
                        h('span', null, __('Model:', 'aiseo-content-studio') + ' ' + latest.model),
                        h('span', null, __('Tokens:', 'aiseo-content-studio') + ' ' + (latest.usage ? latest.usage.total_tokens : 0)),
                        h('span', null, __('Cost:', 'aiseo-content-studio') + ' $' + (latest.cost || 0))
                    ) : null,
                    h('textarea', { rows: 18, value: preview(payload), onChange: function (event) {
                        try { setPayload(JSON.parse(event.target.value)); } catch (ignore) { setPayload(event.target.value); }
                    } }),
                    h('div', { className: 'aiseocs-panel-actions' },
                        button(__('Apply to Product', 'aiseo-content-studio'), apply, 'primary', loading),
                        button(__('Copy', 'aiseo-content-studio'), function () { navigator.clipboard.writeText(preview(payload)); }, 'secondary')
                    )
                ),
                h('div', { className: 'aiseocs-panel-card' },
                    h('h3', null, __('Image AI', 'aiseo-content-studio')),
                    h('p', null, __('Generate product images, banners, lifestyle scenes, transparent PNG prompts, and variations by describing the desired output.', 'aiseo-content-studio')),
                    h('textarea', { rows: 8, value: imagePrompt, onChange: function (event) { setImagePrompt(event.target.value); }, placeholder: __('Example: luxury lifestyle product photo on a clean background, transparent PNG, ecommerce ready…', 'aiseo-content-studio') }),
                    h('div', { className: 'aiseocs-panel-actions' }, button(__('Generate Image', 'aiseo-content-studio'), generateImage, 'accent', loading))
                )
            )
        );
    }

    roots.forEach(function (root) {
        wp.element.render(h(ProductPanel, { root: root, api: createApi(root) }), root);
    });
})(window.wp);
