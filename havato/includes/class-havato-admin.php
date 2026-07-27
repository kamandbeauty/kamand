<?php
/**
 * wp-admin panel: 6 sub-pages sharing one visual language.
 *
 * The native dark WP sidebar is left untouched; only the content column is
 * restyled: white stat cards with soft round colour icons + green growth
 * badges, a clean approval table with a green "verify" pill, blue range
 * sliders for the formula weights, and a dark live console with mac-style
 * traffic lights and monospace [HH:MM:SS] log lines.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Admin UI controller.
 */
class Havato_Admin {

	/**
	 * Hooks.
	 */
	public static function init() {
		add_action( 'admin_menu', array( __CLASS__, 'menu' ) );
		add_action( 'admin_enqueue_scripts', array( __CLASS__, 'assets' ) );
		add_action( 'admin_post_havato_admin_action', array( __CLASS__, 'handle_post' ) );
		add_action( 'admin_notices', array( __CLASS__, 'notices' ) );
	}

	/**
	 * Register the menu and its 6 sub-pages.
	 */
	public static function menu() {
		$cap = 'manage_options';

		add_menu_page(
			'Havato',
			'Havato — هواتو',
			$cap,
			'havato',
			array( __CLASS__, 'page_dashboard' ),
			'dashicons-coffee',
			26
		);

		$pages = array(
			'havato'            => array( 'admin_dashboard', 'page_dashboard' ),
			'havato-approvals'  => array( 'admin_approvals', 'page_approvals' ),
			'havato-revenue'    => array( 'admin_revenue', 'page_revenue' ),
			'havato-matcher'    => array( 'admin_matcher', 'page_matcher' ),
			'havato-weights'    => array( 'admin_weights', 'page_weights' ),
			'havato-google'     => array( 'admin_google', 'page_google' ),
			'havato-locale'     => array( 'admin_locale', 'page_locale' ),
		);

		foreach ( $pages as $slug => $conf ) {
			add_submenu_page(
				'havato',
				Havato_I18N::t( $conf[0] ),
				Havato_I18N::t( $conf[0] ),
				$cap,
				$slug,
				array( __CLASS__, $conf[1] )
			);
		}
	}

	/**
	 * Load the admin CSS/JS only on Havato screens.
	 *
	 * @param string $hook Current screen hook.
	 */
	public static function assets( $hook ) {
		$is_havato = ( false !== strpos( $hook, 'havato' ) );

		// The users.php badges need a sliver of CSS too.
		if ( ! $is_havato && 'users.php' !== $hook ) {
			return;
		}

		wp_enqueue_style( 'havato-admin', HAVATO_URL . 'assets/css/havato-admin.css', array(), HAVATO_VERSION );

		if ( ! $is_havato ) {
			return;
		}

		wp_enqueue_script( 'havato-admin', HAVATO_URL . 'assets/js/havato-admin.js', array(), HAVATO_VERSION, true );

		wp_localize_script(
			'havato-admin',
			'HAVATO_ADMIN',
			array(
				'rest'  => esc_url_raw( rest_url( Havato_REST::NS ) ),
				'nonce' => wp_create_nonce( 'wp_rest' ),
				'lang'  => Havato_I18N::current_lang(),
				'i18n'  => Havato_I18N::flat( Havato_I18N::current_lang() ),
			)
		);
	}

	/**
	 * Flash messages after a POST redirect.
	 */
	public static function notices() {
		// phpcs:ignore WordPress.Security.NonceVerification.Recommended
		if ( empty( $_GET['havato_msg'] ) ) {
			return;
		}
		// phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$msg = sanitize_text_field( wp_unslash( $_GET['havato_msg'] ) );
		printf( '<div class="notice notice-success is-dismissible"><p>%s</p></div>', esc_html( $msg ) );
	}

	/* =====================================================================
	 * Shared chrome
	 * ================================================================== */

	/**
	 * Page header + tab strip.
	 *
	 * @param string $title    Page title.
	 * @param string $subtitle Sub title.
	 */
	private static function head( $title, $subtitle = '' ) {
		// phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$current = isset( $_GET['page'] ) ? sanitize_key( wp_unslash( $_GET['page'] ) ) : 'havato';

		$tabs = array(
			'havato'           => Havato_I18N::t( 'admin_dashboard' ),
			'havato-approvals' => Havato_I18N::t( 'admin_approvals' ),
			'havato-revenue'   => Havato_I18N::t( 'admin_revenue' ),
			'havato-matcher'   => Havato_I18N::t( 'admin_matcher' ),
			'havato-weights'   => Havato_I18N::t( 'admin_weights' ),
			'havato-google'    => Havato_I18N::t( 'admin_google' ),
			'havato-locale'    => Havato_I18N::t( 'admin_locale' ),
		);

		echo '<div class="wrap hv-admin">';
		echo '<div class="hv-admin-head">';
		echo '<div class="hv-admin-brand"><span class="hv-admin-logo">H</span><div>';
		echo '<h1>' . esc_html( $title ) . '</h1>';
		if ( $subtitle ) {
			echo '<p>' . esc_html( $subtitle ) . '</p>';
		}
		echo '</div></div>';
		echo '</div>';

		echo '<nav class="hv-admin-tabs">';
		foreach ( $tabs as $slug => $label ) {
			printf(
				'<a class="hv-admin-tab%s" href="%s">%s</a>',
				$slug === $current ? ' is-active' : '',
				esc_url( admin_url( 'admin.php?page=' . $slug ) ),
				esc_html( $label )
			);
		}
		echo '</nav>';
	}

	/**
	 * Close the wrapper.
	 */
	private static function foot() {
		echo '</div>';
	}

	/**
	 * One stat card.
	 *
	 * @param string $label  Label.
	 * @param string $value  Big number.
	 * @param string $color  blue|green|orange|pink.
	 * @param string $icon   Dashicon suffix.
	 * @param string $growth Growth badge text (optional).
	 */
	private static function stat_card( $label, $value, $color, $icon, $growth = '' ) {
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

	/**
	 * The dark live console.
	 *
	 * @param int    $limit How many lines.
	 * @param string $title Card title.
	 */
	private static function console( $limit = 18, $title = '' ) {
		$lines = Havato_Logger::tail( $limit );

		echo '<div class="hv-adm-console" id="hv-console">';
		echo '<div class="hv-adm-console-bar"><i class="is-red"></i><i class="is-yellow"></i><i class="is-green"></i>';
		echo '<span>' . esc_html( $title ? $title : Havato_I18N::t( 'live_console' ) ) . '</span></div>';
		echo '<div class="hv-adm-console-body" id="hv-console-body">';

		if ( empty( $lines ) ) {
			echo '<p class="hv-line is-info">[--:--:--] Havato matcher engine idle — waiting for events…</p>';
		} else {
			foreach ( $lines as $line ) {
				printf(
					'<p class="hv-line is-%s">[%s] %s</p>',
					esc_attr( $line['level'] ),
					esc_html( $line['time'] ),
					esc_html( $line['msg'] )
				);
			}
		}

		echo '</div></div>';
	}

	/**
	 * Hidden nonce + action fields for the admin-post form handler.
	 *
	 * @param string $action Sub-action name.
	 */
	private static function form_fields( $action ) {
		wp_nonce_field( 'havato_admin', 'havato_nonce' );
		echo '<input type="hidden" name="action" value="havato_admin_action">';
		echo '<input type="hidden" name="havato_action" value="' . esc_attr( $action ) . '">';
	}

	/**
	 * A labelled blue range slider.
	 *
	 * @param string $name  Field name.
	 * @param string $label Label.
	 * @param mixed  $value Current value.
	 * @param int    $min   Min.
	 * @param int    $max   Max.
	 * @param string $unit  Unit suffix.
	 */
	private static function slider( $name, $label, $value, $min = 0, $max = 100, $unit = '' ) {
		printf(
			'<div class="hv-adm-slider">
				<div class="hv-adm-slider-top"><span>%1$s</span><b data-out="%2$s">%3$s%4$s</b></div>
				<input type="range" class="hv-adm-range" name="%2$s" value="%5$s" min="%6$d" max="%7$d" step="1" data-unit="%4$s">
			</div>',
			esc_html( $label ),
			esc_attr( $name ),
			esc_html( $value ),
			esc_attr( $unit ),
			esc_attr( $value ),
			(int) $min,
			(int) $max
		);
	}

	/* =====================================================================
	 * Page 1 — statistics dashboard
	 * ================================================================== */

	/**
	 * Dashboard page.
	 */
	public static function page_dashboard() {
		Havato_DB::ensure_tables();
		$stats = Havato_REST::stats_payload();
		$lang  = Havato_I18N::current_lang();

		$fmt = function ( $n ) use ( $lang ) {
			return 'fa' === $lang ? Havato_Jalali::fa_digits( number_format( (int) $n ) ) : number_format( (int) $n );
		};

		$growth = ( $stats['growth'] >= 0 ? '+' : '' ) . $stats['growth'] . '%';
		if ( 'fa' === $lang ) {
			$growth = Havato_Jalali::fa_digits( $growth );
		}

		self::head( Havato_I18N::t( 'admin_dashboard' ), Havato_I18N::t( 'tagline' ) );

		echo '<div class="hv-adm-stats">';
		self::stat_card( Havato_I18N::t( 'stat_active_users' ), $fmt( $stats['active_users'] ), 'blue', 'groups', $growth );
		self::stat_card( Havato_I18N::t( 'stat_matched_tables' ), $fmt( $stats['matched_tables'] ), 'green', 'yes-alt' );
		self::stat_card( Havato_I18N::t( 'stat_venues' ), $fmt( $stats['venues'] ), 'orange', 'store' );
		self::stat_card( Havato_I18N::t( 'stat_revenue' ), $stats['revenue_label'][ $lang ], 'pink', 'chart-line' );
		echo '</div>';

		echo '<div class="hv-adm-grid">';

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'admin_approvals' ) ) . '</h2>';
		self::render_pending_table( 5 );
		echo '<p><a class="hv-adm-btn hv-adm-btn-ghost" href="' . esc_url( admin_url( 'admin.php?page=havato-approvals' ) ) . '">' .
			esc_html( Havato_I18N::t( 'admin_approvals' ) ) . '</a></p>';
		echo '</div>';

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'live_console' ) ) . '</h2>';
		self::console( 10 );
		echo '</div>';

		echo '</div>';

		// Quick demo seeder — keeps a fresh install from looking broken.
		echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '" class="hv-adm-card">';
		self::form_fields( 'seed' );
		echo '<h2 class="hv-adm-card-title">Demo data</h2>';
		echo '<p class="hv-adm-muted">Create sample cafés, events and a matched table so you can walk through the whole flow immediately.</p>';
		echo '<button type="submit" class="hv-adm-btn hv-adm-btn-blue">Generate demo content</button>';
		echo '</form>';

		self::foot();
	}

	/* =====================================================================
	 * Page 2 — approvals (venues + menus + photo reports)
	 * ================================================================== */

	/**
	 * Approvals page.
	 */
	public static function page_approvals() {
		Havato_DB::ensure_tables();
		self::head( Havato_I18N::t( 'admin_approvals' ), Havato_I18N::t( 'verify_action' ) );

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'stat_venues' ) ) . '</h2>';
		self::render_pending_table( 50 );
		echo '</div>';

		self::render_menu_queue();
		self::render_photo_reports();

		self::foot();
	}

	/* =====================================================================
	 * Page — revenue & settlements (administrator only)
	 * ================================================================== */

	/**
	 * Platform revenue page.
	 *
	 * Ticket income belongs to the platform, so gross revenue, the commission
	 * cut and every café's outstanding balance live here — never in the café
	 * owner portal, which only ever shows that café's own share.
	 */
	public static function page_revenue() {
		global $wpdb;
		Havato_DB::ensure_tables();

		// Refresh the ledger so the figures are always current.
		Havato_Payouts::rebuild_all();

		$lang = Havato_I18N::current_lang();
		$rows = Havato_Payouts::all();

		$gross      = 0;
		$commission = 0;
		$due        = 0;
		$paid       = 0;

		foreach ( $rows as $row ) {
			$gross      += (int) $row['gross_amount'];
			$commission += (int) $row['commission_amount'];
			if ( 'paid' === $row['status'] ) {
				$paid += (int) $row['venue_amount'];
			} else {
				$due += (int) $row['venue_amount'];
			}
		}

		self::head( Havato_I18N::t( 'admin_revenue' ), Havato_I18N::t( 'payout_status' ) );

		echo '<div class="hv-adm-stats">';
		self::stat_card( Havato_I18N::t( 'stat_revenue' ), havato_price( $gross, $lang ), 'blue', 'chart-line' );
		self::stat_card( Havato_I18N::t( 'payout_commission' ), havato_price( $commission, $lang ), 'green', 'chart-pie' );
		self::stat_card( Havato_I18N::t( 'payout_due' ), havato_price( $due, $lang ), 'orange', 'clock' );
		self::stat_card( Havato_I18N::t( 'payout_paid' ), havato_price( $paid, $lang ), 'pink', 'yes-alt' );
		echo '</div>';

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'revenue_by_event' ) ) . '</h2>';
		self::render_event_revenue();
		echo '</div>';

		self::render_payout_ledger();

		self::foot();
	}

	/**
	 * Per-event ticket income (administrator only).
	 */
	private static function render_event_revenue() {
		global $wpdb;

		$events = Havato_DB::table( 'events' );
		$venues = Havato_DB::table( 'venues' );
		$regs   = Havato_DB::table( 'event_registrations' );
		$lang   = Havato_I18N::current_lang();

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			"SELECT e.id, e.event_date, e.event_time, e.status, e.max_capacity,
					v.name AS venue_name, v.name_fa AS venue_name_fa,
					COUNT(r.id) AS guests,
					COALESCE(SUM(r.amount),0) AS income
			 FROM $events e
			 LEFT JOIN $venues v ON v.id = e.venue_id
			 LEFT JOIN $regs r ON r.event_id = e.id
					AND r.status NOT IN ('cancelled','pending_payment')
			 GROUP BY e.id
			 HAVING income > 0
			 ORDER BY e.event_date DESC
			 LIMIT 50",
			ARRAY_A
		);

		if ( empty( $rows ) ) {
			echo '<p class="hv-adm-muted">' . esc_html( Havato_I18N::t( 'empty_state' ) ) . '</p>';
			return;
		}

		$percent = max( 0, min( 100, (int) Havato_Settings::get( 'commission_percent', 20 ) ) );

		echo '<table class="hv-adm-table"><thead><tr>';
		echo '<th>' . esc_html( Havato_I18N::t( 'venue_name' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'payout_period' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'guests_routed' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'stat_revenue' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'payout_commission' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'payout_share' ) ) . '</th>';
		echo '</tr></thead><tbody>';

		foreach ( $rows as $row ) {
			$name   = $row['venue_name_fa'] ? $row['venue_name_fa'] : $row['venue_name'];
			$income = (int) $row['income'];
			$cut    = (int) round( $income * $percent / 100 );

			echo '<tr>';
			echo '<td><strong>' . esc_html( $name ) . '</strong></td>';
			echo '<td>' . esc_html( Havato_Jalali::format( $row['event_date'], $lang ) . ' — ' . substr( $row['event_time'], 0, 5 ) ) . '</td>';
			echo '<td>' . esc_html( $row['guests'] . ' / ' . $row['max_capacity'] ) . '</td>';
			echo '<td><strong>' . esc_html( havato_price( $income, $lang ) ) . '</strong></td>';
			echo '<td>' . esc_html( havato_price( $cut, $lang ) ) . '</td>';
			echo '<td>' . esc_html( havato_price( $income - $cut, $lang ) ) . '</td>';
			echo '</tr>';
		}

		echo '</tbody></table>';
	}

	/**
	 * The venue verification table.
	 *
	 * @param int $limit Rows.
	 */
	private static function render_pending_table( $limit = 20 ) {
		global $wpdb;
		$venues = Havato_DB::table( 'venues' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results( $wpdb->prepare( "SELECT * FROM $venues ORDER BY verified ASC, created_at DESC LIMIT %d", (int) $limit ), ARRAY_A );

		if ( empty( $rows ) ) {
			echo '<p class="hv-adm-muted">' . esc_html( Havato_I18N::t( 'empty_state' ) ) . '</p>';
			return;
		}

		echo '<table class="hv-adm-table"><thead><tr>';
		echo '<th>' . esc_html( Havato_I18N::t( 'col_order' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'col_manager' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'col_location' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'col_status' ) ) . '</th>';
		echo '<th></th></tr></thead><tbody>';

		$i = 1;
		foreach ( $rows as $row ) {
			$manager = get_user_by( 'id', (int) $row['manager_id'] );
			$name    = $row['name_fa'] ? $row['name_fa'] : $row['name'];

			echo '<tr>';
			echo '<td><span class="hv-adm-order">' . esc_html( $i ) . '</span></td>';
			echo '<td><strong>' . esc_html( $name ) . '</strong><br><span class="hv-adm-muted">' .
				esc_html( $manager ? $manager->user_email : '—' ) . '</span></td>';
			echo '<td>' . esc_html( wp_trim_words( (string) $row['address'], 8, '…' ) ) . '</td>';
			echo '<td>' . ( $row['verified']
				? '<span class="hv-adm-badge is-green">✓ ' . esc_html( Havato_I18N::t( 'verified_venue' ) ) . '</span>'
				: '<span class="hv-adm-badge is-yellow">' . esc_html( Havato_I18N::t( 'badge_pending' ) ) . '</span>' ) . '</td>';
			echo '<td class="hv-adm-actions">';

			echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '">';
			self::form_fields( 'verify' );
			echo '<input type="hidden" name="venue_id" value="' . esc_attr( $row['id'] ) . '">';
			echo '<input type="hidden" name="verified" value="' . ( $row['verified'] ? '0' : '1' ) . '">';
			printf(
				'<button type="submit" class="hv-adm-btn %s">%s</button>',
				$row['verified'] ? 'hv-adm-btn-ghost' : 'hv-adm-btn-green',
				esc_html( $row['verified'] ? Havato_I18N::t( 'cancel' ) : Havato_I18N::t( 'verify_action' ) )
			);
			echo '</form>';

			echo '</td></tr>';
			$i++;
		}

		echo '</tbody></table>';
	}

	/**
	 * Pending menu approvals.
	 */
	private static function render_menu_queue() {
		global $wpdb;
		$venues = Havato_DB::table( 'venues' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results( "SELECT * FROM $venues WHERE pending_menu_json <> '' AND pending_menu_json IS NOT NULL", ARRAY_A );

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'menu_pending_badge' ) ) . '</h2>';

		if ( empty( $rows ) ) {
			echo '<p class="hv-adm-muted">' . esc_html( Havato_I18N::t( 'empty_state' ) ) . '</p>';
			echo '</div>';
			return;
		}

		foreach ( $rows as $row ) {
			$items = havato_json( $row['pending_menu_json'] );
			$name  = $row['name_fa'] ? $row['name_fa'] : $row['name'];

			echo '<div class="hv-adm-subcard">';
			echo '<div class="hv-adm-row-between"><strong>' . esc_html( $name ) . '</strong>';
			echo '<span class="hv-adm-badge is-yellow">' . esc_html( count( $items ) ) . '</span></div>';

			// Restaurant-style rows: photo | name + description | price.
			echo '<ul class="hv-adm-menu-list">';
			foreach ( $items as $item ) {
				$img   = isset( $item['image'] ) ? trim( (string) $item['image'] ) : '';
				$desc  = isset( $item['desc'] ) ? trim( (string) $item['desc'] ) : '';
				$price = isset( $item['price'] ) ? (int) $item['price'] : 0;

				echo '<li class="hv-adm-menu-row">';

				if ( $img ) {
					printf(
						'<img class="hv-adm-menu-thumb" src="%s" alt="%s" loading="lazy">',
						esc_url( $img ),
						esc_attr( $item['name'] )
					);
				} else {
					echo '<span class="hv-adm-menu-thumb is-empty"><span class="dashicons dashicons-food"></span></span>';
				}

				echo '<span class="hv-adm-menu-info">';
				echo '<strong>' . esc_html( $item['name'] ) . '</strong>';
				if ( '' !== $desc ) {
					echo '<span class="hv-adm-muted">' . esc_html( $desc ) . '</span>';
				}
				echo '</span>';

				echo '<b class="hv-adm-menu-price">' . esc_html( havato_price( $price ) ) . '</b>';
				echo '</li>';
			}
			echo '</ul>';

			echo '<div class="hv-adm-actions">';
			// NOTE: PHP casts numeric string array keys to integers, so a
			// `'1' => …` key arrives here as int(1). Comparing it with the
			// string '1' via === is always false, which previously labelled the
			// green approve button "reject". Use an explicit list instead.
			$menu_actions = array(
				array(
					'approve' => 1,
					'class'   => 'hv-adm-btn-green',
					'label'   => Havato_I18N::t( 'verify_action' ),
				),
				array(
					'approve' => 0,
					'class'   => 'hv-adm-btn-ghost',
					'label'   => Havato_I18N::t( 'reject' ),
				),
			);

			foreach ( $menu_actions as $menu_action ) {
				echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '">';
				self::form_fields( 'menu' );
				echo '<input type="hidden" name="venue_id" value="' . esc_attr( $row['id'] ) . '">';
				echo '<input type="hidden" name="approve" value="' . esc_attr( $menu_action['approve'] ) . '">';
				printf(
					'<button type="submit" class="hv-adm-btn %s">%s</button>',
					esc_attr( $menu_action['class'] ),
					esc_html( $menu_action['label'] )
				);
				echo '</form>';
			}
			echo '</div></div>';
		}

		echo '</div>';
	}

	/**
	 * Reported photos queue.
	 */
	private static function render_photo_reports() {
		global $wpdb;
		$reports = Havato_DB::table( 'photo_reports' );
		$photos  = Havato_DB::table( 'user_photos' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			"SELECT r.*, p.photo_url, p.user_id
			 FROM $reports r LEFT JOIN $photos p ON p.id = r.photo_id
			 WHERE r.status = 'pending' ORDER BY r.id DESC LIMIT 30",
			ARRAY_A
		);

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'report' ) ) . '</h2>';

		if ( empty( $rows ) ) {
			echo '<p class="hv-adm-muted">' . esc_html( Havato_I18N::t( 'empty_state' ) ) . '</p>';
			echo '</div>';
			return;
		}

		echo '<div class="hv-adm-report-grid">';
		foreach ( $rows as $row ) {
			echo '<div class="hv-adm-report">';
			if ( $row['photo_url'] ) {
				echo '<img src="' . esc_url( $row['photo_url'] ) . '" alt="">';
			}
			echo '<div class="hv-adm-report-meta">';
			echo '<span class="hv-adm-badge is-yellow">' . esc_html( $row['reason'] ) . '</span>';
			echo '<span class="hv-adm-muted">' . esc_html( havato_display_name( (int) $row['user_id'] ) ) . '</span>';
			echo '</div>';

			echo '<div class="hv-adm-actions">';
			foreach ( array( 'remove' => 'hv-adm-btn-danger', 'keep' => 'hv-adm-btn-ghost' ) as $act => $class ) {
				echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '">';
				self::form_fields( 'photo' );
				echo '<input type="hidden" name="report_id" value="' . esc_attr( $row['id'] ) . '">';
				echo '<input type="hidden" name="action_type" value="' . esc_attr( $act ) . '">';
				printf(
					'<button type="submit" class="hv-adm-btn %s">%s</button>',
					esc_attr( $class ),
					esc_html( 'remove' === $act ? Havato_I18N::t( 'delete' ) : Havato_I18N::t( 'confirm' ) )
				);
				echo '</form>';
			}
			echo '</div></div>';
		}
		echo '</div></div>';
	}

	/**
	 * Payout settlement ledger with the "mark as paid" action.
	 */
	private static function render_payout_ledger() {
		$rows = Havato_Payouts::all();
		$lang = Havato_I18N::current_lang();

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'payout_status' ) ) . '</h2>';

		if ( empty( $rows ) ) {
			echo '<p class="hv-adm-muted">' . esc_html( Havato_I18N::t( 'empty_state' ) ) . '</p>';
			echo '</div>';
			return;
		}

		echo '<table class="hv-adm-table"><thead><tr>';
		echo '<th>' . esc_html( Havato_I18N::t( 'venue_name' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'payout_period' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'payout_gross' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'payout_commission' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'payout_share' ) ) . '</th>';
		echo '<th>' . esc_html( Havato_I18N::t( 'col_status' ) ) . '</th>';
		echo '<th></th></tr></thead><tbody>';

		foreach ( $rows as $row ) {
			$name = $row['name_fa'] ? $row['name_fa'] : $row['name'];
			echo '<tr>';
			echo '<td><strong>' . esc_html( $name ) . '</strong></td>';
			echo '<td>' . esc_html( $row['period_label'][ $lang ] ) . '</td>';
			echo '<td>' . esc_html( $row['gross_label'][ $lang ] ) . '</td>';
			echo '<td>' . esc_html( $row['commission_label'][ $lang ] ) . '</td>';
			echo '<td><strong>' . esc_html( $row['share_label'][ $lang ] ) . '</strong></td>';
			echo '<td>' . ( 'paid' === $row['status']
				? '<span class="hv-adm-badge is-green">' . esc_html( Havato_I18N::t( 'payout_paid' ) ) . '</span>'
				: '<span class="hv-adm-badge is-yellow">' . esc_html( Havato_I18N::t( 'payout_due' ) ) . '</span>' ) . '</td>';
			echo '<td class="hv-adm-actions">';

			if ( 'paid' !== $row['status'] ) {
				echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '">';
				self::form_fields( 'payout' );
				echo '<input type="hidden" name="payout_id" value="' . esc_attr( $row['id'] ) . '">';
				echo '<button type="submit" class="hv-adm-btn hv-adm-btn-green">✓ ' . esc_html( Havato_I18N::t( 'payout_paid' ) ) . '</button>';
				echo '</form>';
			}

			echo '</td></tr>';
		}

		echo '</tbody></table></div>';
	}

	/* =====================================================================
	 * Page 3 — run the matcher
	 * ================================================================== */

	/**
	 * Matcher page.
	 */
	public static function page_matcher() {
		global $wpdb;
		Havato_DB::ensure_tables();

		$events = Havato_DB::table( 'events' );
		$venues = Havato_DB::table( 'venues' );
		$regs   = Havato_DB::table( 'event_registrations' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results(
			"SELECT e.*, v.name AS venue_name, v.name_fa AS venue_name_fa,
					(SELECT COUNT(*) FROM $regs r WHERE r.event_id = e.id AND r.status <> 'cancelled') AS taken
			 FROM $events e LEFT JOIN $venues v ON v.id = e.venue_id
			 ORDER BY e.event_date ASC LIMIT 40",
			ARRAY_A
		);

		$lang = Havato_I18N::current_lang();

		self::head( Havato_I18N::t( 'admin_matcher' ), Havato_I18N::t( 'live_console' ) );

		echo '<div class="hv-adm-grid">';

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'explore_title' ) ) . '</h2>';
		echo '<p class="hv-adm-muted">' .
			esc_html__( 'The engine runs automatically when the last seat is taken, and a cron job forces it a few hours before each event. This button is only a manual backup.', 'havato' ) .
			'</p>';

		if ( empty( $rows ) ) {
			echo '<p class="hv-adm-muted">' . esc_html( Havato_I18N::t( 'empty_state' ) ) . '</p>';
		} else {
			echo '<table class="hv-adm-table"><thead><tr>';
			echo '<th>' . esc_html( Havato_I18N::t( 'col_order' ) ) . '</th>';
			echo '<th>' . esc_html( Havato_I18N::t( 'venue_name' ) ) . '</th>';
			echo '<th>' . esc_html( Havato_I18N::t( 'payout_period' ) ) . '</th>';
			echo '<th>' . esc_html( Havato_I18N::t( 'col_status' ) ) . '</th>';
			echo '<th></th></tr></thead><tbody>';

			$i = 1;
			foreach ( $rows as $row ) {
				$name = $row['venue_name_fa'] ? $row['venue_name_fa'] : $row['venue_name'];

				echo '<tr>';
				echo '<td><span class="hv-adm-order">' . esc_html( $i ) . '</span></td>';
				echo '<td><strong>' . esc_html( $name ) . '</strong><br><span class="hv-adm-muted">' .
					esc_html( $row['taken'] . ' / ' . $row['max_capacity'] ) . '</span></td>';
				echo '<td>' . esc_html( Havato_Jalali::format( $row['event_date'], $lang ) . ' — ' . substr( $row['event_time'], 0, 5 ) ) . '</td>';
				echo '<td><span class="hv-adm-badge is-' . ( 'open' === $row['status'] ? 'yellow' : 'green' ) . '">' .
					esc_html( Havato_I18N::t( 'status_' . $row['status'] ) ) . '</span></td>';
				echo '<td class="hv-adm-actions">';
				if ( 'open' === $row['status'] ) {
					printf(
						'<button type="button" class="hv-adm-btn hv-adm-btn-blue" data-run-matcher="%s">%s</button>',
						esc_attr( $row['id'] ),
						esc_html( Havato_I18N::t( 'admin_matcher' ) )
					);
				} else {
					echo '<span class="hv-adm-muted">—</span>';
				}
				echo '</td></tr>';
				$i++;
			}

			echo '</tbody></table>';
		}

		echo '<p><button type="button" class="hv-adm-btn hv-adm-btn-green" data-run-matcher="all">▶ ' .
			esc_html( Havato_I18N::t( 'admin_matcher' ) ) . '</button></p>';
		echo '</div>';

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'live_console' ) ) . '</h2>';
		self::console( 22 );
		echo '</div>';

		echo '</div>';
		self::foot();
	}

	/* =====================================================================
	 * Page 4 — formula weights
	 * ================================================================== */

	/**
	 * Weights page.
	 */
	public static function page_weights() {
		$s = Havato_Settings::all();

		self::head( Havato_I18N::t( 'admin_weights' ), Havato_I18N::t( 'live_console' ) );

		echo '<div class="hv-adm-grid">';

		echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '" class="hv-adm-card">';
		self::form_fields( 'weights' );
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'admin_weights' ) ) . '</h2>';

		self::slider( 'w_location', Havato_I18N::t( 'weight_location' ), $s['w_location'], 0, 100, '%' );
		self::slider( 'w_time', Havato_I18N::t( 'weight_time' ), $s['w_time'], 0, 100, '%' );
		self::slider( 'w_density', Havato_I18N::t( 'weight_density' ), $s['w_density'], 0, 100, '%' );
		self::slider( 'w_shared_interest', 'Shared interest bonus', $s['w_shared_interest'], 0, 40 );
		self::slider( 'w_speaker_listener', 'Speaker × listener bonus', $s['w_speaker_listener'], 0, 40 );
		self::slider( 'w_intro_extro', 'Introvert × extrovert bonus', $s['w_intro_extro'], 0, 40 );
		self::slider( 'w_ambivert', 'Two ambiverts bonus', $s['w_ambivert'], 0, 40 );
		self::slider( 'w_same_vibe', 'Same vibe bonus', $s['w_same_vibe'], 0, 40 );
		self::slider( 'w_age_penalty', 'Age gap penalty (per year)', $s['w_age_penalty'], 0, 12 );
		self::slider( 'w_age_threshold', 'Free age gap (years)', $s['w_age_threshold'], 0, 20 );
		self::slider( 'w_rating', 'Behaviour score weight', $s['w_rating'], 0, 30 );
		self::slider( 'w_gender_balance', 'Gender balance weight', $s['w_gender_balance'], 0, 60 );

		echo '<label class="hv-adm-switch"><input type="checkbox" name="gender_balance_on" value="1" ' .
			checked( 1, (int) $s['gender_balance_on'], false ) . '><span></span>' .
			esc_html__( 'Take table gender balance into account', 'havato' ) . '</label>';

		echo '<div class="hv-adm-fields">';
		printf(
			'<label>%s<input type="number" name="cron_lead_hours" value="%d" min="1" max="72"></label>',
			esc_html__( 'Force matching N hours before the event', 'havato' ),
			(int) $s['cron_lead_hours']
		);
		printf(
			'<label>%s<input type="number" name="auto_complete_hours" value="%d" min="1" max="24"></label>',
			esc_html__( 'Mark the event completed N hours after start', 'havato' ),
			(int) $s['auto_complete_hours']
		);
		printf(
			'<label>%s<input type="number" name="commission_percent" value="%d" min="0" max="100"></label>',
			esc_html__( 'Platform commission (%)', 'havato' ),
			(int) $s['commission_percent']
		);
		printf(
			'<label>%s<input type="number" name="default_ticket_price" value="%d" min="0" step="1000"></label>',
			esc_html__( 'Default ticket price (Toman)', 'havato' ),
			(int) $s['default_ticket_price']
		);
		echo '</div>';

		echo '<button type="submit" class="hv-adm-btn hv-adm-btn-blue">' . esc_html( Havato_I18N::t( 'save' ) ) . '</button>';
		echo '</form>';

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'live_console' ) ) . '</h2>';
		self::console( 16 );
		echo '</div>';

		echo '</div>';
		self::foot();
	}

	/* =====================================================================
	 * Page 5 — Google sign-in
	 * ================================================================== */

	/**
	 * Google settings page.
	 */
	public static function page_google() {
		$s = Havato_Settings::all();

		self::head( Havato_I18N::t( 'admin_google' ), Havato_I18N::t( 'login_google' ) );

		echo '<div class="hv-adm-grid">';

		echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '" class="hv-adm-card">';
		self::form_fields( 'google' );
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'admin_google' ) ) . '</h2>';

		echo '<div class="hv-adm-fields">';
		printf(
			'<label>Client ID<input type="text" name="google_client_id" value="%s" placeholder="xxxxx.apps.googleusercontent.com"></label>',
			esc_attr( $s['google_client_id'] )
		);
		printf(
			'<label>Client secret<input type="password" name="google_client_secret" value="%s" autocomplete="new-password"></label>',
			esc_attr( $s['google_client_secret'] )
		);
		echo '</div>';

		echo '<div class="hv-adm-note">';
		echo '<p><strong>' . esc_html__( 'Authorized JavaScript origin', 'havato' ) . ':</strong> <code>' . esc_html( home_url() ) . '</code></p>';
		echo '<p><strong>' . esc_html__( 'Authorized redirect URI', 'havato' ) . ':</strong> <code>' . esc_html( home_url( '/' ) ) . '</code></p>';
		echo '<p class="hv-adm-muted">' . esc_html__( 'Create the credentials in Google Cloud Console → APIs & Services → Credentials → OAuth client ID (Web application).', 'havato' ) . '</p>';
		echo '</div>';

		echo '<button type="submit" class="hv-adm-btn hv-adm-btn-blue">' . esc_html( Havato_I18N::t( 'save' ) ) . '</button>';
		echo '</form>';

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'col_status' ) ) . '</h2>';
		echo Havato_Google_Auth::is_configured()
			? '<p><span class="hv-adm-badge is-green">✓ ' . esc_html( Havato_I18N::t( 'confirm' ) ) . '</span></p>'
			: '<p><span class="hv-adm-badge is-yellow">' . esc_html( Havato_I18N::t( 'google_not_configured' ) ) . '</span></p>';
		self::console( 10 );
		echo '</div>';

		echo '</div>';
		self::foot();
	}

	/* =====================================================================
	 * Page 6 — language & region
	 * ================================================================== */

	/**
	 * Locale page.
	 */
	public static function page_locale() {
		$s = Havato_Settings::all();

		self::head( Havato_I18N::t( 'admin_locale' ), Havato_I18N::t( 'lang_label' ) );

		echo '<div class="hv-adm-grid">';

		echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '" class="hv-adm-card">';
		self::form_fields( 'locale' );
		echo '<h2 class="hv-adm-card-title">' . esc_html( Havato_I18N::t( 'admin_locale' ) ) . '</h2>';

		echo '<div class="hv-adm-fields">';
		echo '<label>' . esc_html( Havato_I18N::t( 'lang_label' ) ) . '<select name="default_lang">';
		foreach ( Havato_I18N::languages() as $code => $info ) {
			printf(
				'<option value="%s"%s>%s (%s)</option>',
				esc_attr( $code ),
				selected( $code, $s['default_lang'], false ),
				esc_html( $info['label'] ),
				esc_html( strtoupper( $info['dir'] ) )
			);
		}
		echo '</select></label>';

		printf(
			'<label>%s<input type="number" step="0.0001" name="map_center_lat" value="%s"></label>',
			esc_html__( 'Map center latitude', 'havato' ),
			esc_attr( $s['map_center_lat'] )
		);
		printf(
			'<label>%s<input type="number" step="0.0001" name="map_center_lng" value="%s"></label>',
			esc_html__( 'Map center longitude', 'havato' ),
			esc_attr( $s['map_center_lng'] )
		);
		printf(
			'<label>%s<input type="number" name="map_zoom" value="%d" min="3" max="18"></label>',
			esc_html__( 'Default map zoom', 'havato' ),
			(int) $s['map_zoom']
		);
		echo '</div>';

		echo '<label class="hv-adm-switch"><input type="checkbox" name="allow_lang_switch" value="1" ' .
			checked( 1, (int) $s['allow_lang_switch'], false ) . '><span></span>' .
			esc_html__( 'Show the in-app language switcher', 'havato' ) . '</label>';

		echo '<label class="hv-adm-switch"><input type="checkbox" name="photo_auto_approve" value="1" ' .
			checked( 1, (int) $s['photo_auto_approve'], false ) . '><span></span>' .
			esc_html__( 'Auto-approve gallery photos', 'havato' ) . '</label>';

		echo '<button type="submit" class="hv-adm-btn hv-adm-btn-blue">' . esc_html( Havato_I18N::t( 'save' ) ) . '</button>';
		echo '</form>';

		echo '<div class="hv-adm-card">';
		echo '<h2 class="hv-adm-card-title">' . esc_html__( 'Shortcode & app URLs', 'havato' ) . '</h2>';
		echo '<div class="hv-adm-note">';
		echo '<p><code>[havato_app]</code> — ' . esc_html__( 'place it on any page.', 'havato' ) . '</p>';
		echo '<p><strong>WebView / APK:</strong> <code>' . esc_html( Havato_PWA::app_url() ) . '</code></p>';
		echo '<p><strong>Manifest:</strong> <code>' . esc_html( Havato_PWA::url( 'manifest' ) ) . '</code></p>';
		echo '<p><strong>Service worker:</strong> <code>' . esc_html( Havato_PWA::url( 'sw' ) ) . '</code></p>';
		echo '</div>';
		self::console( 10 );
		echo '</div>';

		echo '</div>';
		self::foot();
	}

	/* =====================================================================
	 * POST handler
	 * ================================================================== */

	/**
	 * Handle every admin form submission.
	 */
	public static function handle_post() {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( 'Forbidden', 403 );
		}

		check_admin_referer( 'havato_admin', 'havato_nonce' );

		$action  = isset( $_POST['havato_action'] ) ? sanitize_key( wp_unslash( $_POST['havato_action'] ) ) : '';
		$message = Havato_I18N::t( 'saved' );
		$page    = 'havato';

		switch ( $action ) {
			case 'verify':
				$venue_id = isset( $_POST['venue_id'] ) ? sanitize_text_field( wp_unslash( $_POST['venue_id'] ) ) : '';
				$verified = isset( $_POST['verified'] ) ? (int) $_POST['verified'] : 1;

				global $wpdb;
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->update( Havato_DB::table( 'venues' ), array( 'verified' => $verified ), array( 'id' => $venue_id ), array( '%d' ), array( '%s' ) );
				Havato_REST::sync_venue_events( $venue_id, (bool) $verified );
				Havato_Logger::log( sprintf( 'Venue %s %s by administrator.', $venue_id, $verified ? 'verified' : 'suspended' ), 'success' );
				$page = 'havato-approvals';
				break;

			case 'menu':
				$venue_id = isset( $_POST['venue_id'] ) ? sanitize_text_field( wp_unslash( $_POST['venue_id'] ) ) : '';
				$approve  = ! empty( $_POST['approve'] );

				$request = new WP_REST_Request( 'POST' );
				$request->set_param( 'venue_id', $venue_id );
				$request->set_param( 'approve', $approve );
				Havato_REST::admin_menu_approve( $request );
				$page = 'havato-approvals';
				break;

			case 'photo':
				$request = new WP_REST_Request( 'POST' );
				$request->set_param( 'report_id', isset( $_POST['report_id'] ) ? (int) $_POST['report_id'] : 0 );
				$request->set_param( 'action_type', isset( $_POST['action_type'] ) ? sanitize_key( wp_unslash( $_POST['action_type'] ) ) : 'keep' );
				Havato_REST::admin_photo_report( $request );
				$page = 'havato-approvals';
				break;

			case 'payout':
				Havato_Payouts::mark_paid( isset( $_POST['payout_id'] ) ? (int) $_POST['payout_id'] : 0 );
				$page = 'havato-revenue';
				break;

			case 'weights':
				$keys = array(
					'w_location', 'w_time', 'w_density', 'w_shared_interest', 'w_speaker_listener',
					'w_intro_extro', 'w_ambivert', 'w_same_vibe', 'w_age_penalty', 'w_age_threshold',
					'w_rating', 'w_gender_balance', 'cron_lead_hours', 'auto_complete_hours',
					'commission_percent', 'default_ticket_price',
				);
				$values = array();
				foreach ( $keys as $key ) {
					if ( isset( $_POST[ $key ] ) ) {
						$values[ $key ] = (int) $_POST[ $key ];
					}
				}
				$values['gender_balance_on'] = empty( $_POST['gender_balance_on'] ) ? 0 : 1;
				Havato_Settings::update( $values );
				Havato_Logger::log( 'Matching weights updated by administrator.', 'info' );
				$page = 'havato-weights';
				break;

			case 'google':
				Havato_Settings::update(
					array(
						'google_client_id'     => isset( $_POST['google_client_id'] ) ? sanitize_text_field( wp_unslash( $_POST['google_client_id'] ) ) : '',
						'google_client_secret' => isset( $_POST['google_client_secret'] ) ? sanitize_text_field( wp_unslash( $_POST['google_client_secret'] ) ) : '',
					)
				);
				$page = 'havato-google';
				break;

			case 'locale':
				Havato_Settings::update(
					array(
						'default_lang'       => isset( $_POST['default_lang'] ) ? sanitize_text_field( wp_unslash( $_POST['default_lang'] ) ) : 'fa',
						'map_center_lat'     => isset( $_POST['map_center_lat'] ) ? (float) $_POST['map_center_lat'] : 35.7219,
						'map_center_lng'     => isset( $_POST['map_center_lng'] ) ? (float) $_POST['map_center_lng'] : 51.3347,
						'map_zoom'           => isset( $_POST['map_zoom'] ) ? (int) $_POST['map_zoom'] : 12,
						'allow_lang_switch'  => empty( $_POST['allow_lang_switch'] ) ? 0 : 1,
						'photo_auto_approve' => empty( $_POST['photo_auto_approve'] ) ? 0 : 1,
					)
				);
				$page = 'havato-locale';
				break;

			case 'seed':
				require_once HAVATO_PATH . 'includes/class-havato-seeder.php';
				$result  = Havato_Seeder::run();
				$message = $result['message'];
				break;
		}

		wp_safe_redirect(
			add_query_arg(
				array(
					'page'       => $page,
					'havato_msg' => rawurlencode( $message ),
				),
				admin_url( 'admin.php' )
			)
		);
		exit;
	}
}
