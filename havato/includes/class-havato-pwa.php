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

		// Pre-cache the real enqueued URLs (?ver=…). Without the query string
		// the entries never match what the page actually requests, so the
		// pre-cache silently does nothing.
		// The fonts are pre-cached too. They are first-party as of 1.37.0 and
		// they are what the app is READ in, so having them offline is worth
		// far more than the ~96 KB it costs.
		$assets = wp_json_encode(
			array(
				add_query_arg( 'ver', HAVATO_VERSION, HAVATO_URL . 'assets/css/havato-app.css' ),
				add_query_arg( 'ver', HAVATO_VERSION, HAVATO_URL . 'assets/js/havato-app.js' ),
				add_query_arg( 'ver', HAVATO_VERSION, HAVATO_URL . 'assets/css/havato-fonts.css' ),
				HAVATO_URL . 'assets/fonts/vazirmatn-400.woff2',
				HAVATO_URL . 'assets/fonts/vazirmatn-700.woff2',
			)
		);

		// Only assets that live under the plugin folder may be cached.
		$scope = wp_json_encode( HAVATO_URL );

		echo "/* Havato service worker v{$version} */\n";
		echo "const HV_CACHE = 'havato-v{$version}';\n";
		echo "const HV_ASSETS = {$assets};\n";
		echo "const HV_ASSET_SCOPE = {$scope};\n";
		echo <<<'SW'
self.addEventListener('install', (e) => {
  // Never let one failed asset abort the whole install.
  e.waitUntil(
    caches.open(HV_CACHE)
      .then((c) => Promise.all(HV_ASSETS.map((u) => c.add(u).catch(() => null))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(
    keys.filter((k) => k !== HV_CACHE).map((k) => caches.delete(k))
  )).then(() => self.clients.claim()));
});

/**
 * Anything that can carry a login session must NEVER be served from cache,
 * otherwise signing out appears to do nothing: the stale cached response still
 * says `logged_in: true` after the cookie is gone.
 */
function hvIsPrivate(url, req) {
  // REST API, in both permalink shapes:
  //   /wp-json/…            (pretty permalinks)
  //   /?rest_route=/havato… (plain permalinks — pathname is just "/")
  if (url.pathname.indexOf('/wp-json/') !== -1) { return true; }
  if (url.searchParams.has('rest_route')) { return true; }
  // Admin, login, AJAX, cron.
  if (url.pathname.indexOf('/wp-admin') !== -1) { return true; }
  if (url.pathname.indexOf('wp-login.php') !== -1) { return true; }
  if (url.pathname.indexOf('admin-ajax.php') !== -1) { return true; }
  // Any request that carries credentials.
  if (req.headers.get('Authorization')) { return true; }
  return false;
}

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') { return; }

  let url;
  try { url = new URL(req.url); } catch (err) { return; }

  // Cross-origin (Google, tiles, CDN fonts): let the network handle it.
  if (url.origin !== self.location.origin) { return; }

  // Session-bearing requests bypass the service worker completely.
  if (hvIsPrivate(url, req)) { return; }

  // HTML navigations are NETWORK-FIRST and are never written to the cache.
  // The document embeds HAVATO_BOOT (login state + a REST nonce); caching it
  // is what made a signed-out user still look signed in after a refresh, and
  // what forced a manual cache clear after every plugin update.
  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req).catch(() => caches.match('havato-offline').then(
        (hit) => hit || new Response(
          '<!doctype html><meta charset="utf-8"><title>Havato</title>' +
          '<body style="font-family:system-ui;padding:2rem;text-align:center">' +
          '<h1>Havato</h1><p>offline</p>',
          { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
        )
      ))
    );
    return;
  }

  // Static plugin assets only: cache-first is safe, they are versioned.
  if (req.url.indexOf(HV_ASSET_SCOPE) !== 0) { return; }

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

// The page asks the worker to wipe everything the moment a user signs out.
self.addEventListener('message', (e) => {
  if (!e.data || e.data.type !== 'havato-logout') { return; }
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.map((k) => caches.delete(k)))));
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
