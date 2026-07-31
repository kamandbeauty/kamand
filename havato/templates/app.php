<?php
/**
 * The [havato_app] shell.
 *
 * Everything below the shell is rendered by assets/js/havato-app.js so the
 * whole thing behaves like an SPA inside a WebView (no full page reloads).
 *
 * @package Havato
 *
 * @var string $lang Active language.
 * @var string $dir  Active direction.
 * @var array  $atts Shortcode attributes.
 */

defined( 'ABSPATH' ) || exit;

$havato_view = isset( $atts['view'] ) ? $atts['view'] : 'auto';
?>
<div id="havato-app"
	class="hv-app hv-dir-<?php echo esc_attr( $dir ); ?>"
	data-lang="<?php echo esc_attr( $lang ); ?>"
	data-view="<?php echo esc_attr( $havato_view ); ?>"
	dir="<?php echo esc_attr( $dir ); ?>">

	<!-- Ambient indigo / light-blue glow orbs (mockup background) -->
	<div class="hv-orb hv-orb-1" aria-hidden="true"></div>
	<div class="hv-orb hv-orb-2" aria-hidden="true"></div>

	<?php include HAVATO_PATH . 'templates/parts/icons.php'; ?>

	<!-- Deep indigo gradient header -->
	<header class="hv-header" id="hv-header">
		<div class="hv-header-bg" aria-hidden="true"></div>
		<div class="hv-header-inner">
			<button type="button" class="hv-avatar-btn" id="hv-avatar-btn" aria-label="profile">
				<img src="" alt="" id="hv-header-avatar" class="hv-avatar" hidden>
				<span class="hv-avatar-fallback" id="hv-avatar-fallback">H</span>
			</button>

			<div class="hv-header-titles">
				<span class="hv-header-eyebrow" id="hv-header-eyebrow"></span>
				<h1 class="hv-header-title" id="hv-header-title">Havato</h1>
			</div>

			<!-- Language on top, the per-tab action beneath it. Side by side
			     these two took enough width to truncate the page title on a
			     narrow phone; stacked, the title gets that space back. -->
			<div class="hv-header-tools">
				<!-- Cycling through three languages one tap at a time meant a
				     Persian speaker had to pass through English to reach
				     Turkish. The button opens a list instead. -->
				<div class="hv-lang-wrap">
					<button type="button" class="hv-lang-btn" id="hv-lang-btn"
						aria-label="language" aria-haspopup="listbox" aria-expanded="false">
						<span id="hv-lang-label">EN</span>
						<span class="hv-lang-caret" aria-hidden="true">▾</span>
					</button>
					<ul class="hv-lang-menu" id="hv-lang-menu" role="listbox" hidden></ul>
				</div>

				<!-- The per-tab action used to live on the round button in the
				     bottom bar, where nothing said what it would do. -->
				<button type="button" class="hv-header-action" id="hv-header-action" hidden>
					<svg class="hv-header-action-icon" viewBox="0 0 24 24" aria-hidden="true">
						<use href="#hv-i-filter"></use>
					</svg>
				</button>
			</div>
		</div>

		<!-- Floating status bar (green / orange) — mockup "Nearby Location" pill -->
		<div class="hv-status-strip" id="hv-status-strip" hidden></div>
	</header>

	<!-- Scrollable content: the ONLY scrolling element of the app -->
	<main id="main-tab-content" class="hv-main" tabindex="-1">
		<div class="hv-boot-loader" id="hv-boot-loader">
			<div class="hv-spinner" aria-hidden="true"></div>
		</div>
	</main>

	<!-- Bottom navigation. The bar is a plain rounded panel since v1.31.0 —
	     the notch existed only to seat the floating button. -->
	<nav class="hv-bottom-nav" id="hv-bottom-nav" aria-label="main">
		<svg class="hv-wave" viewBox="0 0 390 84" preserveAspectRatio="none" aria-hidden="true">
			<defs>
				<!-- Stops are classed so the active theme can repaint them;
				     this SVG is the fallback surface on browsers without
				     mask support, so it must follow the palette too. -->
				<linearGradient id="hvWaveGrad" x1="0" y1="0" x2="1" y2="1">
					<stop class="hv-wave-1" offset="0%" stop-color="#232AD1"/>
					<stop class="hv-wave-2" offset="55%" stop-color="#1B1FBF"/>
					<stop class="hv-wave-3" offset="100%" stop-color="#141A6E"/>
				</linearGradient>
			</defs>
			<!-- Flat top edge: the notch was cut for the floating button and
			     would now show the page through a gap above the middle tab. -->
			<path d="M0,16 L390,16 L390,84 L0,84 Z" fill="url(#hvWaveGrad)"></path>
		</svg>

		<!-- The floating button is gone as of v1.31.0: its job (the guest's
		     dashboard) became the Home tab, and five tabs leave no room for
		     a notch in the middle of the bar. -->
		<div class="hv-tabs" id="hv-tabs" role="tablist"></div>
	</nav>

	<!-- Glass modal host -->
	<div class="hv-modal-host" id="hv-modal-host" hidden>
		<div class="hv-modal-backdrop" data-close="1"></div>
		<div class="hv-modal-card" role="dialog" aria-modal="true">
			<button type="button" class="hv-modal-close" data-close="1" aria-label="close">✕</button>
			<div class="hv-modal-body" id="hv-modal-body"></div>
		</div>
	</div>

	<!-- Toasts -->
	<div class="hv-toast-host" id="hv-toast-host" aria-live="polite"></div>

	<!-- Full-screen transition overlay -->
	<div class="hv-redirect" id="hv-redirect" hidden>
		<div class="hv-spinner hv-spinner-lg" aria-hidden="true"></div>
		<p id="hv-redirect-text"></p>
	</div>
</div>
