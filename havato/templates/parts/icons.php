<?php
/**
 * Inline SVG sprite — two-layer gradient vector icons (mockup style).
 *
 * Each symbol pairs a soft gradient "backplate" with a crisp stroke layer, plus
 * complementary pink / yellow / green accents next to the indigo base, exactly
 * like the reference mockup icons.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;
?>
<svg class="hv-sprite" aria-hidden="true" focusable="false" xmlns="http://www.w3.org/2000/svg">
	<defs>
		<linearGradient id="hvGradBlue" x1="0" y1="0" x2="1" y2="1">
			<stop offset="0%" stop-color="#4FA8FF"/>
			<stop offset="100%" stop-color="#1B1FBF"/>
		</linearGradient>
		<linearGradient id="hvGradPink" x1="0" y1="0" x2="1" y2="1">
			<stop offset="0%" stop-color="#FF8FC8"/>
			<stop offset="100%" stop-color="#F0568F"/>
		</linearGradient>
		<linearGradient id="hvGradGreen" x1="0" y1="0" x2="1" y2="1">
			<stop offset="0%" stop-color="#6FE3B0"/>
			<stop offset="100%" stop-color="#12B981"/>
		</linearGradient>
		<linearGradient id="hvGradOrange" x1="0" y1="0" x2="1" y2="1">
			<stop offset="0%" stop-color="#FFC46B"/>
			<stop offset="100%" stop-color="#F97316"/>
		</linearGradient>
		<linearGradient id="hvGradIndigo" x1="0" y1="0" x2="1" y2="1">
			<stop offset="0%" stop-color="#2B2FE0"/>
			<stop offset="100%" stop-color="#141A6E"/>
		</linearGradient>
	</defs>

	<!-- Explore / compass -->
	<symbol id="hv-i-explore" viewBox="0 0 24 24">
		<circle cx="12" cy="12" r="9.2" fill="url(#hvGradBlue)" opacity=".18"/>
		<circle cx="12" cy="12" r="8.4" fill="none" stroke="url(#hvGradBlue)" stroke-width="1.8"/>
		<path d="M15.4 8.6l-2.1 5-5 2.1 2.1-5z" fill="url(#hvGradPink)"/>
		<circle cx="12" cy="12" r="1.15" fill="#fff"/>
	</symbol>

	<!-- Map pin -->
	<symbol id="hv-i-map" viewBox="0 0 24 24">
		<path d="M12 2.6c-3.7 0-6.7 3-6.7 6.7 0 4.9 6.7 12.1 6.7 12.1s6.7-7.2 6.7-12.1c0-3.7-3-6.7-6.7-6.7z" fill="url(#hvGradBlue)" opacity=".2"/>
		<path d="M12 2.6c-3.7 0-6.7 3-6.7 6.7 0 4.9 6.7 12.1 6.7 12.1s6.7-7.2 6.7-12.1c0-3.7-3-6.7-6.7-6.7z" fill="none" stroke="url(#hvGradBlue)" stroke-width="1.8" stroke-linejoin="round"/>
		<circle cx="12" cy="9.3" r="2.6" fill="url(#hvGradGreen)"/>
	</symbol>

	<!-- Chats -->
	<symbol id="hv-i-chat" viewBox="0 0 24 24">
		<path d="M4 6.4c0-1.4 1.1-2.5 2.5-2.5h11c1.4 0 2.5 1.1 2.5 2.5v7c0 1.4-1.1 2.5-2.5 2.5H9.7L5.6 19.4c-.7.6-1.6.1-1.6-.8z" fill="url(#hvGradBlue)" opacity=".2"/>
		<path d="M4 6.4c0-1.4 1.1-2.5 2.5-2.5h11c1.4 0 2.5 1.1 2.5 2.5v7c0 1.4-1.1 2.5-2.5 2.5H9.7L5.6 19.4c-.7.6-1.6.1-1.6-.8z" fill="none" stroke="url(#hvGradBlue)" stroke-width="1.7" stroke-linejoin="round"/>
		<circle cx="8.6" cy="10" r="1.1" fill="url(#hvGradPink)"/>
		<circle cx="12" cy="10" r="1.1" fill="url(#hvGradOrange)"/>
		<circle cx="15.4" cy="10" r="1.1" fill="url(#hvGradGreen)"/>
	</symbol>

	<!-- Profile -->
	<symbol id="hv-i-profile" viewBox="0 0 24 24">
		<circle cx="12" cy="8.2" r="3.7" fill="url(#hvGradBlue)" opacity=".22"/>
		<circle cx="12" cy="8.2" r="3.7" fill="none" stroke="url(#hvGradBlue)" stroke-width="1.8"/>
		<path d="M4.8 20c.5-3.9 3.6-6.2 7.2-6.2s6.7 2.3 7.2 6.2z" fill="url(#hvGradPink)" opacity=".85"/>
	</symbol>

	<!-- Dashboard (owner) -->
	<symbol id="hv-i-dashboard" viewBox="0 0 24 24">
		<rect x="3.2" y="3.2" width="8" height="8" rx="2.4" fill="url(#hvGradBlue)"/>
		<rect x="12.8" y="3.2" width="8" height="5" rx="2.2" fill="url(#hvGradOrange)"/>
		<rect x="3.2" y="12.8" width="8" height="8" rx="2.4" fill="url(#hvGradGreen)" opacity=".9"/>
		<rect x="12.8" y="9.8" width="8" height="11" rx="2.4" fill="url(#hvGradIndigo)" opacity=".9"/>
	</symbol>

	<!-- Venue events (calendar) -->
	<symbol id="hv-i-calendar" viewBox="0 0 24 24">
		<rect x="3.4" y="5" width="17.2" height="15.4" rx="3.4" fill="url(#hvGradBlue)" opacity=".18"/>
		<rect x="3.4" y="5" width="17.2" height="15.4" rx="3.4" fill="none" stroke="url(#hvGradBlue)" stroke-width="1.7"/>
		<path d="M3.4 9.6h17.2" stroke="url(#hvGradBlue)" stroke-width="1.7"/>
		<path d="M8 3.2v3.4M16 3.2v3.4" stroke="url(#hvGradPink)" stroke-width="1.9" stroke-linecap="round"/>
		<circle cx="9" cy="14.2" r="1.4" fill="url(#hvGradGreen)"/>
		<circle cx="13.4" cy="14.2" r="1.4" fill="url(#hvGradOrange)"/>
	</symbol>

	<!-- Menu builder -->
	<symbol id="hv-i-menu" viewBox="0 0 24 24">
		<rect x="4.4" y="2.8" width="15.2" height="18.4" rx="3" fill="url(#hvGradBlue)" opacity=".16"/>
		<rect x="4.4" y="2.8" width="15.2" height="18.4" rx="3" fill="none" stroke="url(#hvGradBlue)" stroke-width="1.7"/>
		<path d="M8 8h8M8 12h8M8 16h5" stroke="url(#hvGradIndigo)" stroke-width="1.7" stroke-linecap="round"/>
		<circle cx="17.6" cy="16.4" r="2.6" fill="url(#hvGradOrange)"/>
	</symbol>

	<!-- Settings -->
	<symbol id="hv-i-settings" viewBox="0 0 24 24">
		<path d="M12 2.8l2 1.6 2.5-.5 1 2.4 2.3 1.1-.5 2.5 1.6 2-1.6 2 .5 2.5-2.3 1.1-1 2.4-2.5-.5-2 1.6-2-1.6-2.5.5-1-2.4-2.3-1.1.5-2.5-1.6-2 1.6-2-.5-2.5 2.3-1.1 1-2.4 2.5.5z" fill="url(#hvGradBlue)" opacity=".2"/>
		<path d="M12 2.8l2 1.6 2.5-.5 1 2.4 2.3 1.1-.5 2.5 1.6 2-1.6 2 .5 2.5-2.3 1.1-1 2.4-2.5-.5-2 1.6-2-1.6-2.5.5-1-2.4-2.3-1.1.5-2.5-1.6-2 1.6-2-.5-2.5 2.3-1.1 1-2.4 2.5.5z" fill="none" stroke="url(#hvGradBlue)" stroke-width="1.5" stroke-linejoin="round"/>
		<circle cx="12" cy="12" r="3.1" fill="url(#hvGradPink)"/>
	</symbol>

	<!-- Filter (FAB default) -->
	<symbol id="hv-i-filter" viewBox="0 0 24 24">
		<path d="M4 6.2h16l-6.2 7.2v5.4l-3.6 1.8v-7.2z" fill="#fff"/>
	</symbol>

	<!-- Plus (FAB alternative) -->
	<symbol id="hv-i-plus" viewBox="0 0 24 24">
		<path d="M12 5.4v13.2M5.4 12h13.2" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/>
	</symbol>

	<!-- Check -->
	<symbol id="hv-i-check" viewBox="0 0 24 24">
		<path d="M5 12.8l4.4 4.4L19 7.6" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
	</symbol>

	<!-- Cup / café -->
	<symbol id="hv-i-cup" viewBox="0 0 24 24">
		<path d="M4.6 8h12v6.2a5 5 0 0 1-5 5H9.6a5 5 0 0 1-5-5z" fill="url(#hvGradBlue)" opacity=".2"/>
		<path d="M4.6 8h12v6.2a5 5 0 0 1-5 5H9.6a5 5 0 0 1-5-5z" fill="none" stroke="url(#hvGradBlue)" stroke-width="1.7" stroke-linejoin="round"/>
		<path d="M16.6 9.6h1.8a2.4 2.4 0 0 1 0 4.8h-1.8" fill="none" stroke="url(#hvGradOrange)" stroke-width="1.7"/>
		<path d="M8.2 3.2c-.8 1.2.8 1.8 0 3M11.8 3.2c-.8 1.2.8 1.8 0 3" stroke="url(#hvGradPink)" stroke-width="1.5" stroke-linecap="round" fill="none"/>
	</symbol>

	<!-- Users / table -->
	<symbol id="hv-i-users" viewBox="0 0 24 24">
		<circle cx="9" cy="8.4" r="3.2" fill="url(#hvGradBlue)"/>
		<circle cx="16.4" cy="9.4" r="2.5" fill="url(#hvGradPink)"/>
		<path d="M2.8 19.4c.5-3.3 3-5.2 6.2-5.2s5.7 1.9 6.2 5.2z" fill="url(#hvGradIndigo)" opacity=".85"/>
		<path d="M16.2 14.4c2.5.1 4.3 1.8 4.8 5h-3.6" fill="url(#hvGradGreen)" opacity=".9"/>
	</symbol>

	<!-- Star -->
	<symbol id="hv-i-star" viewBox="0 0 24 24">
		<path d="M12 3.4l2.7 5.5 6 .9-4.3 4.2 1 6-5.4-2.8-5.4 2.8 1-6L3.3 9.8l6-.9z" fill="url(#hvGradOrange)"/>
	</symbol>


	<!-- Heart -->
	<symbol id="hv-i-heart" viewBox="0 0 24 24">
		<path d="M12 20.4S3.6 15.2 3.6 9.6a4.4 4.4 0 0 1 8.4-1.8 4.4 4.4 0 0 1 8.4 1.8c0 5.6-8.4 10.8-8.4 10.8z" fill="url(#hvGradPink)"/>
	</symbol>

	<!-- Flag / report -->
	<symbol id="hv-i-flag" viewBox="0 0 24 24">
		<path d="M6 3.4v17.2" stroke="url(#hvGradIndigo)" stroke-width="1.9" stroke-linecap="round"/>
		<path d="M7.6 4.6h10.2l-2 3.6 2 3.6H7.6z" fill="url(#hvGradOrange)"/>
	</symbol>

	<!-- Brain (personality test) -->
	<symbol id="hv-i-brain" viewBox="0 0 24 24">
		<path d="M9.4 3.6a3 3 0 0 0-3 3 2.8 2.8 0 0 0-1.6 5 3 3 0 0 0 1.7 4.7 3 3 0 0 0 5.5 1.6V4.9a3 3 0 0 0-2.6-1.3z" fill="url(#hvGradBlue)"/>
		<path d="M14.6 3.6a3 3 0 0 1 3 3 2.8 2.8 0 0 1 1.6 5 3 3 0 0 1-1.7 4.7 3 3 0 0 1-5.5 1.6V4.9a3 3 0 0 1 2.6-1.3z" fill="url(#hvGradPink)"/>
	</symbol>

	<!-- =====================================================================
	     Bottom-navigation icons (monochrome).

	     The colourful sprite symbols above are built for white cards and are
	     cloned through <use>, which puts their shapes inside a SHADOW TREE:
	     a `.hv-tab svg *` rule can never reach them, and each shape hard-codes
	     its own fill="url(#hvGrad…)" anyway. On the dark indigo nav bar the
	     indigo layer became invisible.

	     These variants paint with `currentColor` — an inherited property, so
	     it DOES cross the shadow boundary — letting the tab colour drive them:
	     translucent white when inactive, solid white when active.
	     ================================================================== -->

	<symbol id="hv-i-nav-explore" viewBox="0 0 24 24">
		<circle cx="12" cy="12" r="8.6" fill="none" stroke="currentColor" stroke-width="1.9"/>
		<path d="M15.4 8.6l-2.1 5-5 2.1 2.1-5z" fill="currentColor"/>
	</symbol>

	<symbol id="hv-i-nav-map" viewBox="0 0 24 24">
		<path d="M12 2.6c-3.7 0-6.7 3-6.7 6.7 0 4.9 6.7 12.1 6.7 12.1s6.7-7.2 6.7-12.1c0-3.7-3-6.7-6.7-6.7z"
			fill="none" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/>
		<circle cx="12" cy="9.3" r="2.5" fill="currentColor"/>
	</symbol>

	<symbol id="hv-i-nav-chat" viewBox="0 0 24 24">
		<path d="M4 6.4c0-1.4 1.1-2.5 2.5-2.5h11c1.4 0 2.5 1.1 2.5 2.5v7c0 1.4-1.1 2.5-2.5 2.5H9.7L5.6 19.4c-.7.6-1.6.1-1.6-.8z"
			fill="none" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/>
		<circle cx="8.6" cy="10" r="1.15" fill="currentColor"/>
		<circle cx="12" cy="10" r="1.15" fill="currentColor"/>
		<circle cx="15.4" cy="10" r="1.15" fill="currentColor"/>
	</symbol>

	<symbol id="hv-i-nav-profile" viewBox="0 0 24 24">
		<circle cx="12" cy="8.2" r="3.6" fill="none" stroke="currentColor" stroke-width="1.9"/>
		<path d="M4.9 20c.6-3.8 3.6-6 7.1-6s6.5 2.2 7.1 6"
			fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
	</symbol>

	<symbol id="hv-i-nav-dashboard" viewBox="0 0 24 24">
		<rect x="3.4" y="3.4" width="7.6" height="7.6" rx="2.2" fill="currentColor"/>
		<rect x="13" y="3.4" width="7.6" height="7.6" rx="2.2" fill="none" stroke="currentColor" stroke-width="1.9"/>
		<rect x="3.4" y="13" width="7.6" height="7.6" rx="2.2" fill="none" stroke="currentColor" stroke-width="1.9"/>
		<rect x="13" y="13" width="7.6" height="7.6" rx="2.2" fill="currentColor"/>
	</symbol>

	<symbol id="hv-i-nav-calendar" viewBox="0 0 24 24">
		<rect x="3.4" y="5" width="17.2" height="15.4" rx="3.2" fill="none" stroke="currentColor" stroke-width="1.9"/>
		<path d="M3.4 9.6h17.2" stroke="currentColor" stroke-width="1.9"/>
		<path d="M8 3.2v3.4M16 3.2v3.4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
		<circle cx="9" cy="14.4" r="1.3" fill="currentColor"/>
		<circle cx="13.6" cy="14.4" r="1.3" fill="currentColor"/>
	</symbol>

	<symbol id="hv-i-nav-menu" viewBox="0 0 24 24">
		<rect x="4.4" y="2.8" width="15.2" height="18.4" rx="3" fill="none" stroke="currentColor" stroke-width="1.9"/>
		<path d="M8 8h8M8 12h8M8 16h5" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
	</symbol>

	<symbol id="hv-i-nav-settings" viewBox="0 0 24 24">
		<path d="M12 2.8l2 1.6 2.5-.5 1 2.4 2.3 1.1-.5 2.5 1.6 2-1.6 2 .5 2.5-2.3 1.1-1 2.4-2.5-.5-2 1.6-2-1.6-2.5.5-1-2.4-2.3-1.1.5-2.5-1.6-2 1.6-2-.5-2.5 2.3-1.1 1-2.4 2.5.5z"
			fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>
		<circle cx="12" cy="12" r="3" fill="currentColor"/>
	</symbol>

	<!-- Google G -->
	<symbol id="hv-i-google" viewBox="0 0 24 24">
		<path d="M21.6 12.2c0-.7-.1-1.3-.2-1.9H12v3.7h5.4a4.6 4.6 0 0 1-2 3v2.5h3.2c1.9-1.7 3-4.3 3-7.3z" fill="#4285F4"/>
		<path d="M12 22c2.7 0 5-.9 6.6-2.5l-3.2-2.5c-.9.6-2 1-3.4 1-2.6 0-4.8-1.7-5.6-4.1H3.1v2.6A10 10 0 0 0 12 22z" fill="#34A853"/>
		<path d="M6.4 13.9a6 6 0 0 1 0-3.8V7.5H3.1a10 10 0 0 0 0 9z" fill="#FBBC05"/>
		<path d="M12 5.9c1.5 0 2.8.5 3.8 1.5l2.8-2.8A10 10 0 0 0 3.1 7.5l3.3 2.6C7.2 7.6 9.4 5.9 12 5.9z" fill="#EA4335"/>
	</symbol>
</svg>
