<?php
/**
 * PWA / WebView support: manifest.json + service worker + standalone mode.
 *
 * Serving both files from rewrite rules keeps the plugin self-contained (no
 * files have to be dropped into the site root) and makes the same shortcode
 * usable as the payload of an Android/iOS WebView or a Capacitor bundle.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Progressive web-app layer.
 */
class Havato_PWA {

	/**
	 * Hooks.
	 */
	public static function init() {
		add_action( 'init', array( __CLASS__, 'add_rewrites' ) );
		add_filter( 'query_vars', array( __CLASS__, 'query_vars' ) );
		add_action( 'template_redirect', array( __CLASS__, 'maybe_serve' ) );
		add_action( 'wp_head', array( __CLASS__, 'head_tags' ), 1 );
		add_action( 'init', array( __CLASS__, 'maybe_flush' ), 999 );
	}

	/**
	 * Pretty URLs for the manifest and the service worker.
	 */
	public static function add_rewrites() {
		add_rewrite_rule( '^havato-manifest\.json$', 'index.php?havato_pwa=manifest', 'top' );
		add_rewrite_rule( '^havato-sw\.js$', 'index.php?havato_pwa=sw', 'top' );
	}

	/**
	 * Register the query var.
	 *
	 * @param array $vars Vars.
	 * @return array
	 */
	public static function query_vars( $vars ) {
		$vars[] = 'havato_pwa';
		return $vars;
	}

	/**
	 * Flush rewrites once after activation.
	 */
	public static function maybe_flush() {
		if ( get_option( 'havato_flush_rewrite' ) ) {
			delete_option( 'havato_flush_rewrite' );
			flush_rewrite_rules();
		}
	}

	/**
	 * Manifest / service-worker URLs.
	 *
	 * @param string $what manifest|sw.
	 * @return string
	 */
	public static function url( $what ) {
		if ( get_option( 'permalink_structure' ) ) {
			return home_url( 'manifest' === $what ? '/havato-manifest.json' : '/havato-sw.js' );
		}
		return add_query_arg( 'havato_pwa', $what, home_url( '/' ) );
	}

	/**
	 * Serve the generated files.
	 */
	public static function maybe_serve() {
		$what = get_query_var( 'havato_pwa' );

		// phpcs:ignore WordPress.Security.NonceVerification.Recommended
		if ( ! $what && isset( $_GET['havato_pwa'] ) ) {
			// phpcs:ignore WordPress.Security.NonceVerification.Recommended
			$what = sanitize_key( wp_unslash( $_GET['havato_pwa'] ) );
		}

		if ( 'manifest' === $what ) {
			self::serve_manifest();
		} elseif ( 'sw' === $what ) {
			self::serve_service_worker();
		}
	}

	/**
	 * manifest.json.
	 */
	private static function serve_manifest() {
		nocache_headers();
		header( 'Content-Type: application/manifest+json; charset=utf-8' );

		$lang  = Havato_I18N::current_lang();
		$start = self::app_url();

		$manifest = array(
			'name'             => 'fa' === $lang ? 'هواتو — دورهمی‌های هوشمند' : 'Havato — Smart social tables',
			'short_name'       => 'fa' === $lang ? 'هواتو' : 'Havato',
			'description'      => Havato_I18N::t( 'tagline', $lang ),
			'lang'             => $lang,
			'dir'              => Havato_I18N::dir( $lang ),
			'start_url'        => $start,
			'scope'            => wp_parse_url( home_url( '/' ), PHP_URL_PATH ) ? wp_parse_url( home_url( '/' ), PHP_URL_PATH ) : '/',
			'display'          => 'standalone',
			'orientation'      => 'portrait',
			'background_color' => '#141a4d',
			'theme_color'      => '#1B1FBF',
			'icons'            => array(
				array(
					'src'     => HAVATO_URL . 'assets/img/icon-192.png',
					'sizes'   => '192x192',
					'type'    => 'image/png',
					'purpose' => 'any maskable',
				),
				array(
					'src'     => HAVATO_URL . 'assets/img/icon-512.png',
					'sizes'   => '512x512',
					'type'    => 'image/png',
					'purpose' => 'any maskable',
				),
			),
		);

		echo wp_json_encode( $manifest, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES );
		exit;
	}

	/**
	 * Minimal offline-tolerant service worker.
	 */
	private static function serve_service_worker() {
		nocache_headers();
		header( 'Content-Type: application/javascript; charset=utf-8' );

		$version = HAVATO_VERSION;
		$assets  = wp_json_encode(
			array(
				HAVATO_URL . 'assets/css/havato-app.css',
				HAVATO_URL . 'assets/js/havato-app.js',
			)
		);

		echo "/* Havato service worker v{$version} */\n";
		echo "const HV_CACHE = 'havato-v{$version}';\n";
		echo "const HV_ASSETS = {$assets};\n";
		echo <<<'SW'
self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(HV_CACHE).then((c) => c.addAll(HV_ASSETS)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(
    keys.filter((k) => k !== HV_CACHE).map((k) => caches.delete(k))
  )).then(() => self.clients.claim()));
});
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') { return; }
  const url = new URL(req.url);
  // Never cache the REST API: the app must always show live data.
  if (url.pathname.indexOf('/wp-json/') !== -1) { return; }
  e.respondWith(
    caches.match(req).then((hit) => hit || fetch(req).then((res) => {
      if (res && res.status === 200 && res.type === 'basic') {
        const copy = res.clone();
        caches.open(HV_CACHE).then((c) => c.put(req, copy));
      }
      return res;
    }).catch(() => caches.match(req)))
  );
});
SW;
		exit;
	}

	/**
	 * URL of the page holding the shortcode, in standalone mode.
	 *
	 * @return string
	 */
	public static function app_url() {
		$page_id = (int) get_option( 'havato_app_page_id' );
		$url     = $page_id ? get_permalink( $page_id ) : home_url( '/' );
		return add_query_arg( 'webview', '1', $url );
	}

	/**
	 * Manifest + mobile meta tags, only on pages that host the app.
	 */
	public static function head_tags() {
		if ( ! Havato_Shortcode::is_app_page() ) {
			return;
		}

		printf(
			'<link rel="manifest" href="%s">' . "\n",
			esc_url( self::url( 'manifest' ) )
		);
		echo '<meta name="theme-color" content="#1B1FBF">' . "\n";
		echo '<meta name="mobile-web-app-capable" content="yes">' . "\n";
		echo '<meta name="apple-mobile-web-app-capable" content="yes">' . "\n";
		echo '<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">' . "\n";
		echo '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, viewport-fit=cover, user-scalable=no">' . "\n";
	}
}
