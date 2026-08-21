<?php
/**
 * Full-screen standalone template (WebView / PWA / APK shell).
 *
 * Loads the app without any theme header, footer or sidebar so the shortcode
 * can be wrapped directly by Capacitor / Cordova / a native WebView.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

$havato_lang = Havato_I18N::current_lang();
$havato_dir  = Havato_I18N::dir( $havato_lang );
?>
<!DOCTYPE html>
<html <?php language_attributes(); ?> dir="<?php echo esc_attr( $havato_dir ); ?>" class="havato-html">
<head>
	<meta charset="<?php bloginfo( 'charset' ); ?>">
	<title><?php echo esc_html( Havato_I18N::t( 'app_name', $havato_lang ) ); ?></title>
	<?php wp_head(); ?>
	<style>
		html.havato-html, html.havato-html body {
			margin: 0;
			padding: 0;
			height: 100%;
			overflow: hidden;
			/* Matches the nebula theme's ink (the default since v1.39.0) so
			   the pre-paint shell flashes the cosmic night instead of the old
			   indigo. The app repaints this area itself once it mounts. */
			background: #0f0a1e;
			overscroll-behavior: none;
		}
		html.havato-html body > *:not(#havato-standalone-root) { display: none !important; }
		#havato-standalone-root { display: block; }
	</style>
</head>
<body <?php body_class( 'havato-standalone-body' ); ?>>
	<div id="havato-standalone-root">
		<?php
		while ( have_posts() ) {
			the_post();
			echo do_shortcode( '[havato_app]' );
		}
		?>
	</div>
	<?php wp_footer(); ?>
</body>
</html>
