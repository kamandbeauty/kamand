<?php
/**
 * محیط آزمایش: شبیه‌سازی حداقلی توابع وردپرس/ووکامرس برای اجرای مسیرهای واقعی افزونه.
 *
 * این فایل فقط در تست‌ها استفاده می‌شود و بخشی از بستهٔ افزونه نیست.
 *
 * @package KamandSizeGuide\Tests
 */

// phpcs:disable WordPress.NamingConventions.PrefixAllGlobals

defined( 'ABSPATH' ) || define( 'ABSPATH', '/tmp/wordpress/' );

$GLOBALS['ksg_test'] = array(
	'post_meta'    => array(),
	'term_meta'    => array(),
	'options'      => array(),
	'posts'        => array(),
	'terms'        => array(),
	'term_of_post' => array(),
	'hooks'        => array(
		'actions'  => array(),
		'filters'  => array(),
		'enqueued' => array(),
		'inline'   => array(),
		'localized'=> array(),
	),
	'context'      => array(
		'is_singular_product' => true,
		'is_product'          => true,
		'post_id'             => 101,
	),
);

/**
 * ثبت هوک.
 */
function add_action( $hook, $callback, $priority = 10, $accepted_args = 1 ) {
	$GLOBALS['ksg_test']['hooks']['actions'][ $hook ][ $priority ][] = $callback;

	return true;
}

/**
 * ثبت فیلتر.
 */
function add_filter( $hook, $callback, $priority = 10, $accepted_args = 1 ) {
	$GLOBALS['ksg_test']['hooks']['filters'][ $hook ][ $priority ][] = $callback;

	return true;
}

/**
 * اجرای اکشن‌های ثبت‌شده.
 */
function do_action( $hook, ...$args ) {
	if ( empty( $GLOBALS['ksg_test']['hooks']['actions'][ $hook ] ) ) {
		return;
	}

	$priorities = $GLOBALS['ksg_test']['hooks']['actions'][ $hook ];
	ksort( $priorities );

	foreach ( $priorities as $callbacks ) {
		foreach ( $callbacks as $callback ) {
			call_user_func_array( $callback, $args );
		}
	}
}

/**
 * اعمال فیلترها.
 */
function apply_filters( $hook, $value, ...$args ) {
	if ( empty( $GLOBALS['ksg_test']['hooks']['filters'][ $hook ] ) ) {
		return $value;
	}

	$priorities = $GLOBALS['ksg_test']['hooks']['filters'][ $hook ];
	ksort( $priorities );

	foreach ( $priorities as $callbacks ) {
		foreach ( $callbacks as $callback ) {
			$value = call_user_func_array( $callback, array_merge( array( $value ), $args ) );
		}
	}

	return $value;
}

function did_action( $hook ) { // phpcs:ignore
	return 1;
}

function register_activation_hook( $file, $callback ) {} // phpcs:ignore
function register_deactivation_hook( $file, $callback ) {} // phpcs:ignore
function flush_rewrite_rules() {} // phpcs:ignore
function load_plugin_textdomain( $domain, $deprecated = false, $path = '' ) { return true; } // phpcs:ignore

function plugin_dir_path( $file ) { return rtrim( dirname( $file ), '/' ) . '/'; } // phpcs:ignore
function plugin_dir_url( $file ) { return 'https://example.test/wp-content/plugins/' . basename( dirname( $file ) ) . '/'; } // phpcs:ignore
function plugin_basename( $file ) { return basename( dirname( $file ) ) . '/' . basename( $file ); } // phpcs:ignore
function plugins_url( $path = '', $plugin = '' ) { return 'https://example.test/wp-content/plugins/' . $path; } // phpcs:ignore

function __( $text, $domain = null ) { return $text; } // phpcs:ignore
function _e( $text, $domain = null ) { echo $text; } // phpcs:ignore
function esc_html__( $text, $domain = null ) { return esc_html( $text ); } // phpcs:ignore
function esc_attr__( $text, $domain = null ) { return esc_attr( $text ); } // phpcs:ignore
function esc_html_e( $text, $domain = null ) { echo esc_html( $text ); } // phpcs:ignore
function esc_attr_e( $text, $domain = null ) { echo esc_attr( $text ); } // phpcs:ignore

function _n( $single, $plural, $number, $domain = null ) { return 1 === (int) $number ? $single : $plural; } // phpcs:ignore

function esc_html( $text ) { return htmlspecialchars( (string) $text, ENT_QUOTES, 'UTF-8' ); } // phpcs:ignore
function esc_attr( $text ) { return htmlspecialchars( (string) $text, ENT_QUOTES, 'UTF-8' ); } // phpcs:ignore
function esc_url( $url ) { return filter_var( $url, FILTER_SANITIZE_URL ); } // phpcs:ignore
function esc_textarea( $text ) { return esc_html( $text ); } // phpcs:ignore
function wp_kses_post( $text ) { return $text; } // phpcs:ignore

function sanitize_text_field( $text ) { // phpcs:ignore
	$text = (string) $text;
	$text = preg_replace( '/<[^>]*>/', '', $text );
	$text = str_replace( array( "\n", "\r", "\t" ), ' ', $text );

	return trim( preg_replace( '/\s+/', ' ', $text ) );
}

function sanitize_textarea_field( $text ) { // phpcs:ignore
	$text = preg_replace( '/<[^>]*>/', '', (string) $text );

	return trim( $text );
}

function sanitize_key( $key ) { // phpcs:ignore
	return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $key ) );
}

function sanitize_hex_color( $color ) { // phpcs:ignore
	if ( preg_match( '/^#([A-Fa-f0-9]{3}){1,2}$/', (string) $color ) ) {
		return $color;
	}

	return null;
}

function sanitize_title( $title ) { // phpcs:ignore
	$title = strtolower( trim( (string) $title ) );
	$title = preg_replace( '/\s+/', '-', $title );

	return preg_replace( '/[^a-z0-9_\-\x{0600}-\x{06FF}]/u', '', $title );
}

function absint( $value ) { return abs( (int) $value ); } // phpcs:ignore
function wp_unslash( $value ) { return is_string( $value ) ? stripslashes( $value ) : $value; } // phpcs:ignore

function wp_parse_args( $args, $defaults = array() ) { // phpcs:ignore
	if ( is_object( $args ) ) {
		$args = get_object_vars( $args );
	}

	return array_merge( (array) $defaults, (array) $args );
}

function wp_json_encode( $data, $options = 0, $depth = 512 ) { return json_encode( $data, $options, $depth ); } // phpcs:ignore
function wp_rand( $min = 0, $max = 0 ) { return random_int( $min, $max ); } // phpcs:ignore
function wp_list_pluck( $list, $field ) { // phpcs:ignore
	$result = array();
	foreach ( (array) $list as $item ) {
		$result[] = is_array( $item ) ? $item[ $field ] : $item->{$field};
	}

	return $result;
}

function maybe_unserialize( $value ) { // phpcs:ignore
	if ( is_string( $value ) && preg_match( '/^[aOs]:\d+:|^\{/', $value ) ) {
		return unserialize( $value ); // phpcs:ignore
	}

	return $value;
}

/* ---------- داده‌ها ---------- */

function get_post_meta( $post_id, $key = '', $single = false ) { // phpcs:ignore
	$store = $GLOBALS['ksg_test']['post_meta'];

	if ( isset( $store[ $post_id ][ $key ] ) ) {
		return $single ? $store[ $post_id ][ $key ] : array( $store[ $post_id ][ $key ] );
	}

	return $single ? '' : array();
}

function update_post_meta( $post_id, $key, $value ) { // phpcs:ignore
	$GLOBALS['ksg_test']['post_meta'][ $post_id ][ $key ] = $value;

	return true;
}

function delete_post_meta_by_key( $key ) { // phpcs:ignore
	foreach ( $GLOBALS['ksg_test']['post_meta'] as $post_id => $meta ) {
		unset( $GLOBALS['ksg_test']['post_meta'][ $post_id ][ $key ] );
	}

	return true;
}

function get_post_meta_by_key( $key ) { // phpcs:ignore
	$rows = array();

	foreach ( $GLOBALS['ksg_test']['post_meta'] as $post_id => $meta ) {
		if ( isset( $meta[ $key ] ) ) {
			$rows[] = array(
				'post_id'    => $post_id,
				'meta_key'   => $key,
				'meta_value' => is_array( $meta[ $key ] ) ? serialize( $meta[ $key ] ) : $meta[ $key ], // phpcs:ignore
			);
		}
	}

	return $rows;
}

function get_term_meta( $term_id, $key = '', $single = false ) { // phpcs:ignore
	$store = $GLOBALS['ksg_test']['term_meta'];

	if ( isset( $store[ $term_id ][ $key ] ) ) {
		return $single ? $store[ $term_id ][ $key ] : array( $store[ $term_id ][ $key ] );
	}

	return $single ? '' : array();
}

function update_term_meta( $term_id, $key, $value ) { // phpcs:ignore
	$GLOBALS['ksg_test']['term_meta'][ $term_id ][ $key ] = $value;

	return true;
}

function delete_term_meta( $term_id, $key ) { // phpcs:ignore
	unset( $GLOBALS['ksg_test']['term_meta'][ $term_id ][ $key ] );

	return true;
}

function get_option( $name, $default = false ) { // phpcs:ignore
	return array_key_exists( $name, $GLOBALS['ksg_test']['options'] ) ? $GLOBALS['ksg_test']['options'][ $name ] : $default;
}

function add_option( $name, $value, $deprecated = '', $autoload = 'yes' ) { // phpcs:ignore
	if ( array_key_exists( $name, $GLOBALS['ksg_test']['options'] ) ) {
		return false;
	}

	$GLOBALS['ksg_test']['options'][ $name ] = $value;

	return true;
}

function update_option( $name, $value, $autoload = null ) { // phpcs:ignore
	$GLOBALS['ksg_test']['options'][ $name ] = $value;

	return true;
}

function delete_option( $name ) { // phpcs:ignore
	unset( $GLOBALS['ksg_test']['options'][ $name ] );

	return true;
}

/**
 * افزودن نوشتهٔ آزمایشی.
 */
function ksg_test_add_post( $id, $title, $type = 'ksg_size_guide', $parent = 0 ) { // phpcs:ignore
	$GLOBALS['ksg_test']['posts'][ $id ] = (object) array(
		'ID'          => $id,
		'post_title'  => $title,
		'post_type'   => $type,
		'post_status' => 'publish',
		'post_parent' => $parent,
	);

	return $id;
}

function get_post( $id = null ) { // phpcs:ignore
	$id = null === $id ? get_the_ID() : (int) $id;

	return isset( $GLOBALS['ksg_test']['posts'][ $id ] ) ? $GLOBALS['ksg_test']['posts'][ $id ] : null;
}

function get_post_type( $id = null ) { // phpcs:ignore
	$post = get_post( $id );

	return $post ? $post->post_type : false;
}

function get_the_title( $id = 0 ) { // phpcs:ignore
	$post = get_post( $id );

	return $post ? $post->post_title : '';
}

function get_the_ID() { // phpcs:ignore
	return (int) $GLOBALS['ksg_test']['context']['post_id'];
}

function get_posts( $args = array() ) { // phpcs:ignore
	$type   = isset( $args['post_type'] ) ? $args['post_type'] : 'post';
	$status = isset( $args['post_status'] ) ? $args['post_status'] : 'publish';
	$ids    = isset( $args['fields'] ) && 'ids' === $args['fields'];
	$found  = array();

	foreach ( $GLOBALS['ksg_test']['posts'] as $post ) {
		if ( $post->post_type !== $type ) {
			continue;
		}

		if ( 'any' !== $status && $post->post_status !== $status ) {
			continue;
		}

		$found[] = $ids ? $post->ID : $post;
	}

	usort(
		$found,
		static function ( $a, $b ) use ( $ids ) {
			if ( $ids ) {
				return $a <=> $b;
			}

			return strcmp( $a->post_title, $b->post_title );
		}
	);

	return $found;
}

function wp_insert_post( $args, $wp_error = false ) { // phpcs:ignore
	$id = 9000 + count( $GLOBALS['ksg_test']['posts'] ) + 1;

	ksg_test_add_post(
		$id,
		isset( $args['post_title'] ) ? $args['post_title'] : '',
		isset( $args['post_type'] ) ? $args['post_type'] : 'post'
	);

	return $id;
}

function wp_delete_post( $id, $force = false ) { // phpcs:ignore
	unset( $GLOBALS['ksg_test']['posts'][ $id ] );

	return true;
}

function is_wp_error( $thing ) { return $thing instanceof WP_Error; } // phpcs:ignore

class WP_Error { // phpcs:ignore
	public $code;

	public function __construct( $code = '' ) {
		$this->code = $code;
	}
}

/**
 * افزودن دسته‌بندی آزمایشی.
 */
function ksg_test_add_term( $id, $name, $parent = 0 ) { // phpcs:ignore
	$GLOBALS['ksg_test']['terms'][ $id ] = (object) array(
		'term_id' => $id,
		'name'    => $name,
		'parent'  => $parent,
	);

	return $id;
}

function get_term( $id, $taxonomy = '' ) { // phpcs:ignore
	return isset( $GLOBALS['ksg_test']['terms'][ $id ] ) ? $GLOBALS['ksg_test']['terms'][ $id ] : null;
}

function get_the_terms( $post_id, $taxonomy ) { // phpcs:ignore
	$ids = isset( $GLOBALS['ksg_test']['term_of_post'][ $post_id ] ) ? $GLOBALS['ksg_test']['term_of_post'][ $post_id ] : array();
	$out = array();

	foreach ( $ids as $id ) {
		$term = get_term( $id, $taxonomy );
		if ( $term ) {
			$out[] = $term;
		}
	}

	return $out;
}

function get_terms( $args = array() ) { // phpcs:ignore
	$ids = array();

	foreach ( $GLOBALS['ksg_test']['terms'] as $term ) {
		$ids[] = $term->term_id;
	}

	return $ids;
}

function wp_get_attachment_image( $id, $size = 'thumbnail', $icon = false, $attr = array() ) { // phpcs:ignore
	$class = isset( $attr['class'] ) ? $attr['class'] : '';

	return '<img src="https://example.test/img-' . absint( $id ) . '.jpg" class="' . esc_attr( $class ) . '" alt="" />';
}

/* ---------- شرایط و قالب ---------- */

function is_singular( $type = '' ) { // phpcs:ignore
	return ! empty( $GLOBALS['ksg_test']['context']['is_singular_product'] );
}

function is_product() { // phpcs:ignore
	return ! empty( $GLOBALS['ksg_test']['context']['is_product'] );
}

function is_admin() { return false; } // phpcs:ignore
function current_user_can( $cap ) { return true; } // phpcs:ignore
function wp_verify_nonce( $nonce, $action ) { return 1; } // phpcs:ignore
function wp_nonce_field( $action, $name = '_wpnonce', $referer = true, $echo = true ) { // phpcs:ignore
	$html = '<input type="hidden" name="' . esc_attr( $name ) . '" value="stub-nonce" />';
	if ( $echo ) {
		echo $html;
	}

	return $html;
}
function check_admin_referer( $action ) { return true; } // phpcs:ignore
function wp_safe_redirect( $url ) { return true; } // phpcs:ignore
function admin_url( $path = '' ) { return 'https://example.test/wp-admin/' . ltrim( $path, '/' ); } // phpcs:ignore
function add_query_arg( $args, $url = '' ) { return $url . '?' . http_build_query( (array) $args ); } // phpcs:ignore
function wp_die( $message = '' ) { throw new Exception( is_string( $message ) ? $message : 'wp_die' ); } // phpcs:ignore
function get_current_screen() { return (object) array( 'post_type' => 'product' ); } // phpcs:ignore

/* ---------- صف دارایی‌ها ---------- */

function wp_register_style( $handle, $src = '', $deps = array(), $ver = false ) { // phpcs:ignore
	$GLOBALS['ksg_test']['hooks']['enqueued'][ $handle ] = 'registered';

	return true;
}

function wp_enqueue_style( $handle, $src = '', $deps = array(), $ver = false ) { // phpcs:ignore
	$GLOBALS['ksg_test']['hooks']['enqueued'][ $handle ] = 'enqueued';

	return true;
}

function wp_register_script( $handle, $src = '', $deps = array(), $ver = false, $in_footer = false ) { // phpcs:ignore
	$GLOBALS['ksg_test']['hooks']['enqueued'][ $handle ] = 'registered';

	return true;
}

function wp_enqueue_script( $handle, $src = '', $deps = array(), $ver = false, $in_footer = false ) { // phpcs:ignore
	$GLOBALS['ksg_test']['hooks']['enqueued'][ $handle ] = 'enqueued';

	return true;
}

function wp_add_inline_style( $handle, $css ) { // phpcs:ignore
	$GLOBALS['ksg_test']['hooks']['inline'][ $handle ] = $css;

	return true;
}

function wp_add_inline_script( $handle, $js, $position = 'after' ) { // phpcs:ignore
	$GLOBALS['ksg_test']['hooks']['inline'][ 'script:' . $handle ] = $js;

	return true;
}

function wp_localize_script( $handle, $name, $data ) { // phpcs:ignore
	$GLOBALS['ksg_test']['hooks']['localized'][ $handle ] = array(
		'name' => $name,
		'data' => $data,
	);

	return true;
}

function wp_style_is( $handle, $status = 'enqueued' ) { // phpcs:ignore
	return isset( $GLOBALS['ksg_test']['hooks']['enqueued'][ $handle ] );
}

function wp_enqueue_media( $args = array() ) { return true; } // phpcs:ignore
function submit_button( $text = '', $type = 'primary', $name = 'submit', $wrap = true ) { echo '<button>' . esc_html( $text ) . '</button>'; } // phpcs:ignore
function settings_fields( $group ) { echo '<input type="hidden" name="option_page" value="' . esc_attr( $group ) . '" />'; } // phpcs:ignore
function register_setting( $group, $name, $args = array() ) { return true; } // phpcs:ignore
function add_submenu_page( $parent, $title, $menu, $cap, $slug, $callback ) { return $slug; } // phpcs:ignore
function add_meta_box( $id, $title, $callback, $screen = null, $context = 'advanced', $priority = 'default', $args = null ) { // phpcs:ignore
	$GLOBALS['ksg_test']['meta_boxes'][ $id ] = $callback;

	return true;
}
function register_post_type( $type, $args = array() ) { // phpcs:ignore
	$GLOBALS['ksg_test']['post_types'][ $type ] = $args;

	return true;
}
function add_shortcode( $tag, $callback ) { // phpcs:ignore
	$GLOBALS['ksg_test']['shortcodes'][ $tag ] = $callback;

	return true;
}

/**
 * اجرای شورت‌کد ثبت‌شده.
 */
function ksg_do_shortcode( $tag, $atts = array() ) { // phpcs:ignore
	$callback = $GLOBALS['ksg_test']['shortcodes'][ $tag ];

	return call_user_func( $callback, $atts );
}

function shortcode_atts( $pairs, $atts, $shortcode = '' ) { // phpcs:ignore
	$atts = (array) $atts;
	$out  = array();

	foreach ( $pairs as $name => $default ) {
		$out[ $name ] = array_key_exists( $name, $atts ) ? $atts[ $name ] : $default;
	}

	return $out;
}

function checked( $checked, $current = true, $echo = true ) { // phpcs:ignore
	$result = (string) $checked === (string) $current ? " checked='checked'" : '';
	if ( $echo ) {
		echo $result;
	}

	return $result;
}

function selected( $selected, $current = true, $echo = true ) { // phpcs:ignore
	$result = (string) $selected === (string) $current ? " selected='selected'" : '';
	if ( $echo ) {
		echo $result;
	}

	return $result;
}

/**
 * محصول ووکامرس ساختگی برای آزمون محصولات متغیر.
 */
class KSG_Test_Product { // phpcs:ignore
	private $type;
	private $attributes;

	public function __construct( $type = 'variable', $attributes = array() ) {
		$this->type       = $type;
		$this->attributes = $attributes;
	}

	public function is_type( $type ) {
		return $this->type === $type;
	}

	public function get_variation_attributes() {
		return $this->attributes;
	}
}

/**
 * تعیین محصول ساختگی جاری.
 */
function ksg_test_set_product( $product ) { // phpcs:ignore
	$GLOBALS['ksg_test']['product'] = $product;
}

function wc_get_product( $id = 0 ) { // phpcs:ignore
	return isset( $GLOBALS['ksg_test']['product'] ) ? $GLOBALS['ksg_test']['product'] : false;
}

class WooCommerce {} // phpcs:ignore

/**
 * بازنشانی وضعیت آزمون.
 */
function ksg_test_reset() { // phpcs:ignore
	$GLOBALS['ksg_test']['post_meta']    = array();
	$GLOBALS['ksg_test']['term_meta']    = array();
	$GLOBALS['ksg_test']['options']      = array();
	$GLOBALS['ksg_test']['posts']        = array();
	$GLOBALS['ksg_test']['terms']        = array();
	$GLOBALS['ksg_test']['term_of_post'] = array();
	$GLOBALS['ksg_test']['product']      = null;
}
