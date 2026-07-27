<?php
/**
 * Shared wp-admin UI primitives.
 *
 * Used by both the platform admin panel (Havato_Admin) and the café owner
 * panel (Havato_Owner_Admin) so the two screens stay visually identical.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Reusable admin widgets.
 */
class Havato_Admin_UI {

	/**
	 * White stat card: round colour icon, label, big number, optional growth.
	 *
	 * @param string $label  Label.
	 * @param string $value  Big number.
	 * @param string $color  blue|green|orange|pink.
	 * @param string $icon   Dashicon suffix.
	 * @param string $growth Growth badge text (optional).
	 */
	public static function stat_card( $label, $value, $color, $icon, $growth = '' ) {
		echo '<div class="hv-adm-stat">';
		echo '<div class="hv-adm-stat-icon is-' . esc_attr( $color ) . '"><span class="dashicons dashicons-' . esc_attr( $icon ) . '"></span></div>';
		echo '<div class="hv-adm-stat-body">';
		echo '<span class="hv-adm-stat-label">' . esc_html( $label ) . '</span>';
		if ( '' !== $growth ) {
			echo '<span class="hv-adm-growth">' . esc_html( $growth ) . '</span>';
		}
		echo '<span class="hv-adm-stat-value">' . esc_html( $value ) . '</span>';
		echo '</div></div>';
	}
}
