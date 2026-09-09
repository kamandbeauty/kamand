<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Saina_TO_Frontend {

	public static function init() {
		add_shortcode( 'saina_track_order', array( __CLASS__, 'shortcode' ) );
		add_shortcode( 'saina_progress', array( __CLASS__, 'progress_shortcode' ) );
		add_action( 'wp_enqueue_scripts', array( __CLASS__, 'assets' ) );
		add_action( 'woocommerce_order_details_after_order_table', array( __CLASS__, 'account_progress' ) );
		add_action( 'woocommerce_my_account_my_orders_column_saina-status', array( __CLASS__, 'account_column' ) );
		add_filter( 'woocommerce_account_orders_columns', array( __CLASS__, 'add_column' ) );
		add_action( 'woocommerce_email_after_order_table', array( __CLASS__, 'email_block' ), 20, 4 );
		add_action( 'woocommerce_admin_order_data_after_shipping_address', array( __CLASS__, 'admin_after_address' ) );
	}

	public static function assets() {
		wp_enqueue_style( 'saina-to-front', SAINA_TO_URL . 'public/css/frontend.css', array(), SAINA_TO_VERSION );
		wp_enqueue_script( 'saina-to-front', SAINA_TO_URL . 'public/js/frontend.js', array(), SAINA_TO_VERSION, true );
		$a = wp_rand( 2, 9 );
		$b = wp_rand( 1, 8 );
		wp_localize_script(
			'saina-to-front',
			'sainaTO',
			array(
				'ajax'         => admin_url( 'admin-ajax.php' ),
				'nonce'        => wp_create_nonce( 'saina_to_front' ),
				'captchaLabel' => Saina_TO_Helpers::to_fa( $a ) . ' + ' . Saina_TO_Helpers::to_fa( $b ) . ' = ؟',
				'captchaHash'  => wp_hash( ( $a + $b ) . '|' . wp_salt( 'nonce' ) ),
			)
		);
	}

	public static function shortcode() {
		$settings = Saina_TO_Helpers::get_settings();
		$mode     = $settings['track_mode'];
		ob_start();
		?>
		<div class="saina-track" data-mode="<?php echo esc_attr( $mode ); ?>">
			<form class="saina-track-form">
				<div class="saina-tabs">
					<button type="button" class="is-active" data-tab="order">شماره سفارش</button>
					<?php if ( 'order_email' !== $mode ) : ?>
						<button type="button" data-tab="mobile">موبایل</button>
					<?php endif; ?>
					<?php if ( 'order_mobile' !== $mode ) : ?>
						<button type="button" data-tab="email">ایمیل</button>
					<?php endif; ?>
					<button type="button" data-tab="combo">ترکیبی</button>
				</div>
				<label class="saina-field saina-f-order">
					<span>شماره سفارش</span>
					<input type="text" name="order_id" placeholder="مثلاً ۱۰۴۲" />
				</label>
				<label class="saina-field saina-f-mobile" style="display:none">
					<span>شماره موبایل</span>
					<input type="text" name="mobile" placeholder="۰۹۱۲۱۲۳۴۵۶۷" />
				</label>
				<label class="saina-field saina-f-email" style="display:none">
					<span>ایمیل سفارش</span>
					<input type="email" name="email" placeholder="you@email.com" dir="ltr" />
				</label>
				<?php if ( 'math' === $settings['captcha'] ) : ?>
					<label class="saina-field saina-captcha">
						<span class="saina-captcha-q"><?php echo esc_html( '' ); ?></span>
						<input type="text" name="captcha" placeholder="پاسخ" />
						<input type="hidden" name="captcha_hash" />
					</label>
				<?php endif; ?>
				<button type="submit" class="saina-submit">پیگیری سفارش</button>
			</form>
			<div class="saina-results"></div>
		</div>
		<?php
		return ob_get_clean();
	}

	public static function progress_shortcode( $atts ) {
		$atts  = shortcode_atts( array( 'order' => 0 ), $atts );
		$order = wc_get_order( absint( $atts['order'] ) );
		if ( ! $order ) {
			return '';
		}
		return self::render_progress( $order, Saina_TO_Helpers::get_settings() );
	}

	public static function render_order_card( $order, $settings ) {
		if ( 'yes' === $settings['disable_virtual'] && Saina_TO_Helpers::order_is_virtual( $order ) ) {
			return '<div class="saina-card">این سفارش مجازی است و رهگیری پستی ندارد.</div>';
		}
		$t       = Saina_TO_Helpers::get_order_tracking( $order );
		$carrier = Saina_TO_Helpers::carriers();
		$cid     = $t['carrier'] ? $t['carrier'] : 'post';
		$cname   = Saina_TO_Helpers::carrier_name( $cid );
		ob_start();
		?>
		<div class="saina-card" data-order="<?php echo esc_attr( $order->get_id() ); ?>">
			<div class="saina-card-head">
				<div>
					<div class="saina-muted">شماره سفارش</div>
					<strong>#<?php echo esc_html( Saina_TO_Helpers::to_fa( $order->get_order_number() ) ); ?></strong>
				</div>
				<div><?php echo esc_html( wc_get_order_status_name( $order->get_status() ) ); ?></div>
			</div>
			<?php
			if ( 'yes' === $settings['progress_bar'] ) {
				echo self::render_progress( $order, $settings ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			}
			?>
			<ul class="saina-items">
				<?php foreach ( $order->get_items() as $item ) : ?>
					<li><?php echo esc_html( $item->get_name() ); ?> × <?php echo esc_html( Saina_TO_Helpers::to_fa( $item->get_quantity() ) ); ?></li>
				<?php endforeach; ?>
			</ul>
			<div class="saina-ship">
				<?php if ( $t['code'] ) : ?>
					<div>کد رهگیری: <b><?php echo esc_html( $t['code'] ); ?></b></div>
					<div>حمل‌ونقل: <?php echo esc_html( $cname ); ?></div>
					<div>تاریخ ارسال: <?php echo esc_html( Saina_TO_Helpers::to_fa( $t['ship_date'] ) ); ?></div>
					<div>تاریخ تحویل: <?php echo esc_html( Saina_TO_Helpers::to_fa( $t['delivery_date'] ) ); ?></div>
					<div class="saina-actions">
						<?php if ( in_array( $cid, array( 'post', 'post-custom' ), true ) ) : ?>
							<a class="saina-btn post" target="_blank" rel="noopener" href="<?php echo esc_url( $carrier['post']['url'] ); ?>">پیگیری از پست</a>
						<?php elseif ( 'chapar' === $cid ) : ?>
							<a class="saina-btn chapar" target="_blank" rel="noopener" href="<?php echo esc_url( $carrier['chapar']['url'] ); ?>">پیگیری از چاپار</a>
						<?php elseif ( 'tipax' === $cid ) : ?>
							<a class="saina-btn tipax" target="_blank" rel="noopener" href="<?php echo esc_url( $carrier['tipax']['url'] ); ?>">پیگیری از تیپاکس</a>
						<?php endif; ?>
						<?php if ( 'yes' === $settings['confirm_delivery'] && 'completed' === $order->get_status() ) : ?>
							<button type="button" class="saina-confirm" data-order="<?php echo esc_attr( $order->get_id() ); ?>">کالا را تحویل گرفتم</button>
						<?php endif; ?>
					</div>
				<?php else : ?>
					<p>هنوز کد رهگیری پستی برای این سفارش ثبت نشده است.</p>
				<?php endif; ?>
			</div>
		</div>
		<?php
		return ob_get_clean();
	}

	public static function render_progress( $order, $settings ) {
		$idx      = Saina_TO_Helpers::status_index( $order->get_status() );
		$statuses = $settings['statuses'];
		$keys     = array( 'processing', 'on-hold', 'packing', 'completed', 'delivered' );
		ob_start();
		?>
		<div class="saina-progress">
			<?php foreach ( $keys as $i => $key ) : ?>
				<?php
				$done    = $i < $idx;
				$current = $i === $idx;
				$label   = isset( $statuses[ $key ]['label'] ) ? $statuses[ $key ]['label'] : $key;
				$color   = isset( $statuses[ $key ]['color'] ) ? $statuses[ $key ]['color'] : '#0d9488';
				$cls     = $done ? 'is-done' : ( $current ? 'is-current' : '' );
				?>
				<div class="saina-step <?php echo esc_attr( $cls ); ?>" style="--c:<?php echo esc_attr( $color ); ?>">
					<span class="saina-dot"></span>
					<small><?php echo esc_html( $label ); ?></small>
				</div>
			<?php endforeach; ?>
		</div>
		<?php
		return ob_get_clean();
	}

	public static function account_progress( $order ) {
		$settings = Saina_TO_Helpers::get_settings();
		if ( 'yes' !== $settings['progress_bar'] ) {
			return;
		}
		if ( 'yes' === $settings['disable_virtual'] && Saina_TO_Helpers::order_is_virtual( $order ) ) {
			return;
		}
		echo self::render_order_card( $order, $settings ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
	}

	public static function add_column( $columns ) {
		$settings = Saina_TO_Helpers::get_settings();
		if ( 'yes' !== $settings['icons_column'] ) {
			return $columns;
		}
		$columns['saina-status'] = 'ارسال';
		return $columns;
	}

	public static function account_column( $order ) {
		$t = Saina_TO_Helpers::get_order_tracking( $order );
		if ( empty( $t['code'] ) ) {
			echo '—';
			return;
		}
		printf(
			'<span class="saina-tip" title="%s">📦</span>',
			esc_attr( $t['code'] . ' | ' . Saina_TO_Helpers::carrier_name( $t['carrier'] ) . ' | ' . $t['ship_date'] )
		);
	}

	public static function email_block( $order, $sent_to_admin, $plain_text, $email ) {
		$settings = Saina_TO_Helpers::get_settings();
		if ( 'yes' !== $settings['email_embed'] ) {
			return;
		}
		$t = Saina_TO_Helpers::get_order_tracking( $order );
		if ( empty( $t['code'] ) ) {
			return;
		}
		echo '<h2>جزئیات ارسال ساینا</h2>';
		echo '<p>کد رهگیری: <strong>' . esc_html( $t['code'] ) . '</strong><br>';
		echo 'حمل‌ونقل: ' . esc_html( Saina_TO_Helpers::carrier_name( $t['carrier'] ) ) . '<br>';
		echo 'تاریخ ارسال: ' . esc_html( $t['ship_date'] ) . '<br>';
		echo 'تاریخ تحویل: ' . esc_html( $t['delivery_date'] ) . '</p>';
	}

	public static function admin_after_address( $order ) {
		$t = Saina_TO_Helpers::get_order_tracking( $order );
		if ( empty( $t['code'] ) ) {
			return;
		}
		echo '<p><strong>ساینا:</strong> ' . esc_html( $t['code'] ) . ' / ' . esc_html( Saina_TO_Helpers::carrier_name( $t['carrier'] ) ) . '</p>';
	}
}
