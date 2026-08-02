<?php
namespace AISEO\Core;

class AI_Seo_Studio {
    private static $instance = null;
    public static function instance() { return self::$instance ??= new self(); }
    public function __construct() {
        add_action('admin_menu', [$this, 'add_menu']);
        add_action('admin_enqueue_scripts', [$this, 'enqueue']);
        add_action('wp_ajax_ai_seo_generate', [$this, 'ajax_generate']);
        add_action('rest_api_init', [$this, 'register_routes']);
    }
    public static function activate() { require_once AISEO_DIR . 'includes/class-ai-seo-studio-activator.php'; \AISEO\Activatator\Activator::run(); }
    public static function deactivate() {}
    public static function uninstall() { require_once AISEO_DIR . 'includes/class-ai-seo-studio-uninstall.php'; \AISEO\Uninstall\Uninstall::run(); }
    public function add_menu() { add_menu_page('AI SEO Studio', 'AI SEO Studio', 'manage_options', 'ai-seo-studio', [$this,'render_dash'], 'dashicons-robot', 3); add_submenu_page('ai-seo-studio','Dashboard','Dashboard','manage_options','ai-seo-studio'); add_submenu_page('ai-seo-studio','WooCommerce AI','WooCommerce AI','manage_options','ai-seo-wc',[$this,'render_wc']); }
    public function enqueue($hook) { if(strpos($hook,'ai-seo')===false) return; wp_enqueue_style('ai-seo-style',AISEO_URL.'assets/css/style.css',[],AISEO_VERSION); wp_enqueue_script('ai-seo-app',AISEO_URL.'assets/js/app.js',['jquery'],AISEO_VERSION,true); wp_localize_script('ai-seo-app','aiSeo',['ajax_url'=>admin_url('admin-ajax.php'),'nonce'=>wp_create_nonce('ai_seo_nonce'),'rest_url'=>esc_url_raw(rest_url('ai-seo/v1/'))]); }
    public function render_dash() { include AISEO_DIR . 'admin/dashboard.php'; }
    public function render_wc() { include AISEO_DIR . 'admin/woocommerce-panel.php'; }
    public function ajax_generate() { check_ajax_referer('ai_seo_nonce','nonce'); $provider=sanitize_text_field($_POST['provider']??'openai'); $prompt=sanitize_textarea_field($_POST['prompt']??''); wp_send_json_success(['content'=>'Generated AI content for '.$provider.'. Prompt: '.esc_html($prompt)]); }
    public function register_routes() { register_rest_route('ai-seo/v1','/generate', ['methods'=>'POST','callback'=>[$this,'rest_generate'],'permission_callback'=>[$this,'rest_perm']]); }
    public function rest_perm() { return current_user_can('manage_options'); }
    public function rest_generate(\WP_REST_Request $req) { $data=$req->get_json_params(); return new \WP_REST_Response(['status'=>'ok','provider'=>sanitize_text_field($data['provider']??'openai'),'result'=>'AI output generated securely.']); }
}
