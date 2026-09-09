<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Saina_TO_Admin {

	public static function init() {
		add_action( 'admin_menu', array( __CLASS__, 'menu' ) );
		add_action( 'admin_enqueue_scripts', array( __CLASS__, 'assets' ) );
		add_action( 'add_meta_boxes', array( __CLASS__, 'metabox' ) );
		add_action( 'woocommerce_process_shop_order_meta', array( __CLASS__, 'save_metabox' ) );
		add_action( 'woocommerce_process_order_meta', array( __CLASS__, 'save_metabox' ) );
		add_filter( 'manage_edit-shop_order_columns', array( __CLASS__, 'column' ), 20 );
		add_filter( 'manage_woocommerce_page_wc-orders_columns', array( __CLASS__, 'column' ), 20 );
		add_action( 'manage_shop_order_posts_custom_column', array( __CLASS__, 'column_value' ), 10, 2 );
		add_action( 'manage_woocommerce_page_wc-orders_custom_column', array( __CLASS__, 'column_value' ), 10, 2 );
		add_action( 'admin_post_saina_import_csv', array( __CLASS__, 'handle_import' ) );
		add_action( 'admin_post_saina_bulk_save', array( __CLASS__, 'handle_bulk' ) );
		add_action( 'admin_init', array( __CLASS__, 'save_settings' ) );
	}

	public static function menu() {
		add_menu_page(
			'ساینا پیگیری سفارشات',
			'ساینا ترک‌اوردر',
			'manage_woocommerce',
			'saina-track-order',
			array( __CLASS__, 'page_settings' ),
			'dashicons-location-alt',
			56
		);
		add_submenu_page( 'saina-track-order', 'تنظیمات', 'تنظیمات', 'manage_woocommerce', 'saina-track-order', array( __CLASS__, 'page_settings' ) );
		add_submenu_page( 'saina-track-order', 'درج گروهی', 'درج گروهی کد رهگیری', 'manage_woocommerce', 'saina-track-bulk', array( __CLASS__, 'page_bulk' ) );
		add_submenu_page( 'saina-track-order', 'درون‌ریزی اکسل', 'درون‌ریزی اکسل', 'manage_woocommerce', 'saina-track-import', array( __CLASS__, 'page_import' ) );
	}

	public static function assets( $hook ) {
		if ( false === strpos( $hook, 'saina-track' ) && 'post.php' !== $hook && 'woocommerce_page_wc-orders' !== $hook ) {
			return;
		}
		wp_enqueue_style( 'saina-to-admin', SAINA_TO_URL . 'admin/css/admin.css', array(), SAINA_TO_VERSION );
		wp_enqueue_script( 'saina-to-admin', SAINA_TO_URL . 'admin/js/admin.js', array( 'jquery' ), SAINA_TO_VERSION, true );
	}

	public static function metabox() {
		$screens = array( 'shop_order', 'woocommerce_page_wc-orders' );
		foreach ( $screens as $screen ) {
			add_meta_box(
				'saina_to_box',
				'جزئیات ارسال ساینا',
				array( __CLASS__, 'metabox_html' ),
				$screen,
				'side',
				'high'
			);
		}
	}

	public static function metabox_html( $post ) {
		$order = ( $post instanceof WC_Order ) ? $post : wc_get_order( $post->ID );
		if ( ! $order ) {
			return;
		}
		$t        = Saina_TO_Helpers::get_order_tracking( $order );
		$settings = Saina_TO_Helpers::get_settings();
		wp_nonce_field( 'saina_to_meta', 'saina_to_nonce' );
		?>
		<p>
			<label>کد رهگیری</label>
			<input type="text" class="widefat" name="saina_tracking_code" value="<?php echo esc_attr( $t['code'] ); ?>" />
		</p>
		<p>
			<label>سیستم حمل‌ونقل</label>
			<select name="saina_carrier" class="widefat">
				<?php foreach ( Saina_TO_Helpers::carriers() as $id => $c ) : ?>
					<option value="<?php echo esc_attr( $id ); ?>" <?php selected( $t['carrier'] ? $t['carrier'] : $settings['default_carrier'], $id ); ?>><?php echo esc_html( $c['name'] ); ?></option>
				<?php endforeach; ?>
			</select>
		</p>
		<p>
			<label>تاریخ ارسال (شمسی)</label>
			<input type="text" class="widefat saina-jalali" name="saina_ship_date" value="<?php echo esc_attr( $t['ship_date'] ); ?>" placeholder="1404/06/18" />
		</p>
		<p>
			<label>تاریخ تحویل (شمسی)</label>
			<input type="text" class="widefat saina-jalali" name="saina_delivery_date" value="<?php echo esc_attr( $t['delivery_date'] ); ?>" placeholder="1404/06/21" />
		</p>
		<p>
			<label>
				<input type="checkbox" name="saina_send_sms" value="1" checked />
				افزودن شورتکدها به پیامک وضعیت
			</label>
		</p>
		<?php
	}

	public static function save_metabox( $order_id ) {
		if ( ! isset( $_POST['saina_to_nonce'] ) || ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['saina_to_nonce'] ) ), 'saina_to_meta' ) ) {
			return;
		}
		$order = wc_get_order( $order_id );
		if ( ! $order ) {
			return;
		}
		Saina_TO_Helpers::save_order_tracking(
			$order,
			array(
				'code'          => wp_unslash( $_POST['saina_tracking_code'] ?? '' ),
				'carrier'       => wp_unslash( $_POST['saina_carrier'] ?? '' ),
				'ship_date'     => wp_unslash( $_POST['saina_ship_date'] ?? '' ),
				'delivery_date' => wp_unslash( $_POST['saina_delivery_date'] ?? '' ),
			)
		);
	}

	public static function column( $columns ) {
		$columns['saina_track'] = 'ساینا';
		return $columns;
	}

	public static function column_value( $column, $post_id ) {
		if ( 'saina_track' !== $column ) {
			return;
		}
		$order = $post_id instanceof WC_Order ? $post_id : wc_get_order( $post_id );
		if ( ! $order ) {
			return;
		}
		$t = Saina_TO_Helpers::get_order_tracking( $order );
		if ( empty( $t['code'] ) ) {
			echo '—';
			return;
		}
		printf(
			'<span title="%s">🚚 %s</span>',
			esc_attr( $t['code'] . ' | ' . Saina_TO_Helpers::carrier_name( $t['carrier'] ) ),
			esc_html( $t['code'] )
		);
	}

	public static function save_settings() {
		if ( ! isset( $_POST['saina_to_save_settings'] ) ) {
			return;
		}
		if ( ! current_user_can( 'manage_woocommerce' ) ) {
			return;
		}
		check_admin_referer( 'saina_to_settings' );
		$current = Saina_TO_Helpers::get_settings();
		$fields  = array( 'progress_bar', 'icons_column', 'ajax_search', 'confirm_delivery', 'disable_virtual', 'email_embed', 'sms_enabled' );
		foreach ( $fields as $f ) {
			$current[ $f ] = isset( $_POST[ $f ] ) ? 'yes' : 'no';
		}
		$current['captcha']           = sanitize_text_field( wp_unslash( $_POST['captcha'] ?? 'math' ) );
		$current['track_mode']        = sanitize_text_field( wp_unslash( $_POST['track_mode'] ?? 'any' ) );
		$current['default_carrier']   = sanitize_text_field( wp_unslash( $_POST['default_carrier'] ?? 'post' ) );
		$current['auto_deliver_days'] = absint( $_POST['auto_deliver_days'] ?? 7 );
		$current['recaptcha_site']    = sanitize_text_field( wp_unslash( $_POST['recaptcha_site'] ?? '' ) );
		$current['recaptcha_secret']  = sanitize_text_field( wp_unslash( $_POST['recaptcha_secret'] ?? '' ) );
		if ( isset( $_POST['status_label'] ) && is_array( $_POST['status_label'] ) ) {
			foreach ( $current['statuses'] as $key => $row ) {
				if ( isset( $_POST['status_label'][ $key ] ) ) {
					$current['statuses'][ $key ]['label'] = sanitize_text_field( wp_unslash( $_POST['status_label'][ $key ] ) );
				}
				if ( isset( $_POST['status_color'][ $key ] ) ) {
					$current['statuses'][ $key ]['color'] = sanitize_hex_color( wp_unslash( $_POST['status_color'][ $key ] ) );
				}
			}
		}
		Saina_TO_Helpers::update_settings( $current );
		add_settings_error( 'saina_to', 'saved', 'تنظیمات ساینا ذخیره شد.', 'updated' );
	}

	public static function page_settings() {
		$s = Saina_TO_Helpers::get_settings();
		settings_errors( 'saina_to' );
		?>
		<div class="wrap saina-wrap">
			<h1>تنظیمات ساینا | پیگیری سفارشات</h1>
			<p>شورتکد فرم پیگیری: <code>[saina_track_order]</code></p>
			<form method="post">
				<?php wp_nonce_field( 'saina_to_settings' ); ?>
				<table class="form-table">
					<tr><th>نوار پیشرفت</th><td><label><input type="checkbox" name="progress_bar" <?php checked( $s['progress_bar'], 'yes' ); ?> /> نمایش در فرم و حساب کاربری</label></td></tr>
					<tr><th>ستون آیکن</th><td><label><input type="checkbox" name="icons_column" <?php checked( $s['icons_column'], 'yes' ); ?> /> ستون ارسال در سفارش‌های من</label></td></tr>
					<tr><th>جستجوی Ajax</th><td><label><input type="checkbox" name="ajax_search" <?php checked( $s['ajax_search'], 'yes' ); ?> /> فعال</label></td></tr>
					<tr><th>تأیید دریافت</th><td><label><input type="checkbox" name="confirm_delivery" <?php checked( $s['confirm_delivery'], 'yes' ); ?> /> مشتری بتواند تحویل را تأیید کند</label></td></tr>
					<tr><th>محصولات مجازی</th><td><label><input type="checkbox" name="disable_virtual" <?php checked( $s['disable_virtual'], 'yes' ); ?> /> غیرفعال برای دانلودی/مجازی</label></td></tr>
					<tr><th>ایمیل ووکامرس</th><td><label><input type="checkbox" name="email_embed" <?php checked( $s['email_embed'], 'yes' ); ?> /> درج جزئیات ارسال در ایمیل</label></td></tr>
					<tr>
						<th>حالت فرم</th>
						<td>
							<select name="track_mode">
								<option value="any" <?php selected( $s['track_mode'], 'any' ); ?>>سفارش یا موبایل یا ایمیل</option>
								<option value="order_mobile" <?php selected( $s['track_mode'], 'order_mobile' ); ?>>سفارش + موبایل</option>
								<option value="order_email" <?php selected( $s['track_mode'], 'order_email' ); ?>>سفارش + ایمیل</option>
							</select>
						</td>
					</tr>
					<tr>
						<th>کپچا</th>
						<td>
							<select name="captcha">
								<option value="none" <?php selected( $s['captcha'], 'none' ); ?>>بدون کپچا</option>
								<option value="math" <?php selected( $s['captcha'], 'math' ); ?>>کپچای عددی</option>
								<option value="recaptcha2" <?php selected( $s['captcha'], 'recaptcha2' ); ?>>reCAPTCHA v2</option>
								<option value="recaptcha3" <?php selected( $s['captcha'], 'recaptcha3' ); ?>>reCAPTCHA v3</option>
							</select>
							<p><input type="text" class="regular-text" name="recaptcha_site" value="<?php echo esc_attr( $s['recaptcha_site'] ); ?>" placeholder="Site key" /></p>
							<p><input type="text" class="regular-text" name="recaptcha_secret" value="<?php echo esc_attr( $s['recaptcha_secret'] ); ?>" placeholder="Secret key" /></p>
						</td>
					</tr>
					<tr>
						<th>حامل پیش‌فرض</th>
						<td>
							<select name="default_carrier">
								<?php foreach ( Saina_TO_Helpers::carriers() as $id => $c ) : ?>
									<option value="<?php echo esc_attr( $id ); ?>" <?php selected( $s['default_carrier'], $id ); ?>><?php echo esc_html( $c['name'] ); ?></option>
								<?php endforeach; ?>
							</select>
						</td>
					</tr>
					<tr>
						<th>تبدیل خودکار به تحویل‌شده</th>
						<td><input type="number" name="auto_deliver_days" value="<?php echo esc_attr( $s['auto_deliver_days'] ); ?>" /> روز پس از تکمیل</td>
					</tr>
				</table>
				<h2>شخصی‌سازی وضعیت‌ها</h2>
				<table class="form-table">
					<?php foreach ( $s['statuses'] as $key => $row ) : ?>
						<tr>
							<th><?php echo esc_html( $key ); ?></th>
							<td>
								<input type="text" name="status_label[<?php echo esc_attr( $key ); ?>]" value="<?php echo esc_attr( $row['label'] ); ?>" />
								<input type="color" name="status_color[<?php echo esc_attr( $key ); ?>]" value="<?php echo esc_attr( $row['color'] ); ?>" />
							</td>
						</tr>
					<?php endforeach; ?>
				</table>
				<p><button class="button button-primary" name="saina_to_save_settings" value="1">ذخیره تنظیمات</button></p>
			</form>
			<h2>شورتکد پیامک ووکامرس فارسی</h2>
			<p><code>{tracking_code}</code> <code>{carrier}</code> <code>{ship_date}</code> <code>{delivery_date}</code> <code>{order_id}</code></p>
		</div>
		<?php
	}

	public static function page_bulk() {
		$paged  = max( 1, absint( $_GET['paged'] ?? 1 ) );
		$orders = wc_get_orders(
			array(
				'limit'    => 10,
				'page'     => $paged,
				'paginate' => true,
				'status'   => array( 'processing', 'on-hold', 'saina-packing', 'completed' ),
			)
		);
		$settings = Saina_TO_Helpers::get_settings();
		?>
		<div class="wrap saina-wrap">
			<h1>درج گروهی کد رهگیری</h1>
			<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
				<input type="hidden" name="action" value="saina_bulk_save" />
				<?php wp_nonce_field( 'saina_bulk' ); ?>
				<table class="widefat striped">
					<thead>
						<tr><th>سفارش</th><th>مشتری</th><th>کد رهگیری</th><th>حامل</th><th>ارسال</th><th>تحویل</th></tr>
					</thead>
					<tbody>
					<?php foreach ( $orders->orders as $order ) : $t = Saina_TO_Helpers::get_order_tracking( $order ); ?>
						<tr>
							<td>#<?php echo esc_html( $order->get_id() ); ?><input type="hidden" name="ids[]" value="<?php echo esc_attr( $order->get_id() ); ?>" /></td>
							<td><?php echo esc_html( $order->get_formatted_billing_full_name() ); ?></td>
							<td><input type="text" name="code[<?php echo esc_attr( $order->get_id() ); ?>]" value="<?php echo esc_attr( $t['code'] ); ?>" /></td>
							<td>
								<select name="carrier[<?php echo esc_attr( $order->get_id() ); ?>]">
									<?php foreach ( Saina_TO_Helpers::carriers() as $id => $c ) : ?>
										<option value="<?php echo esc_attr( $id ); ?>" <?php selected( $t['carrier'] ? $t['carrier'] : $settings['default_carrier'], $id ); ?>><?php echo esc_html( $c['name'] ); ?></option>
									<?php endforeach; ?>
								</select>
							</td>
							<td><input type="text" name="ship[<?php echo esc_attr( $order->get_id() ); ?>]" value="<?php echo esc_attr( $t['ship_date'] ); ?>" class="saina-jalali" /></td>
							<td><input type="text" name="delivery[<?php echo esc_attr( $order->get_id() ); ?>]" value="<?php echo esc_attr( $t['delivery_date'] ); ?>" class="saina-jalali" /></td>
						</tr>
					<?php endforeach; ?>
					</tbody>
				</table>
				<p><button class="button button-primary">ذخیره</button></p>
			</form>
		</div>
		<?php
	}

	public static function page_import() {
		?>
		<div class="wrap saina-wrap">
			<h1>درون‌ریزی اکسل / CSV</h1>
			<p>ستون‌ها: <code>order_id,tracking_code,carrier,ship_date,delivery_date</code> — شناسایی بر اساس شماره سفارش (مناسب دکان).</p>
			<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" enctype="multipart/form-data">
				<input type="hidden" name="action" value="saina_import_csv" />
				<?php wp_nonce_field( 'saina_import' ); ?>
				<input type="file" name="csv" accept=".csv,text/csv" required />
				<p><button class="button button-primary">درون‌ریزی</button></p>
			</form>
		</div>
		<?php
	}

	public static function handle_bulk() {
		if ( ! current_user_can( 'manage_woocommerce' ) ) {
			wp_die( 'forbidden' );
		}
		check_admin_referer( 'saina_bulk' );
		$ids = isset( $_POST['ids'] ) ? array_map( 'absint', wp_unslash( $_POST['ids'] ) ) : array();
		foreach ( $ids as $id ) {
			$order = wc_get_order( $id );
			if ( ! $order ) {
				continue;
			}
			Saina_TO_Helpers::save_order_tracking(
				$order,
				array(
					'code'          => $_POST['code'][ $id ] ?? '',
					'carrier'       => $_POST['carrier'][ $id ] ?? '',
					'ship_date'     => $_POST['ship'][ $id ] ?? '',
					'delivery_date' => $_POST['delivery'][ $id ] ?? '',
				)
			);
		}
		wp_safe_redirect( admin_url( 'admin.php?page=saina-track-bulk&saved=1' ) );
		exit;
	}

	public static function handle_import() {
		if ( ! current_user_can( 'manage_woocommerce' ) ) {
			wp_die( 'forbidden' );
		}
		check_admin_referer( 'saina_import' );
		if ( empty( $_FILES['csv']['tmp_name'] ) ) {
			wp_safe_redirect( admin_url( 'admin.php?page=saina-track-import&err=1' ) );
			exit;
		}
		$handle = fopen( $_FILES['csv']['tmp_name'], 'r' ); // phpcs:ignore
		$header = fgetcsv( $handle );
		$map    = array();
		foreach ( $header as $i => $col ) {
			$map[ strtolower( trim( $col ) ) ] = $i;
		}
		while ( ( $row = fgetcsv( $handle ) ) !== false ) {
			$oid = isset( $map['order_id'] ) ? absint( $row[ $map['order_id'] ] ) : 0;
			if ( ! $oid ) {
				continue;
			}
			$order = wc_get_order( $oid );
			if ( ! $order ) {
				continue;
			}
			Saina_TO_Helpers::save_order_tracking(
				$order,
				array(
					'code'          => $row[ $map['tracking_code'] ?? $map['code'] ?? 1 ] ?? '',
					'carrier'       => $row[ $map['carrier'] ?? 2 ] ?? 'post',
					'ship_date'     => $row[ $map['ship_date'] ?? 3 ] ?? '',
					'delivery_date' => $row[ $map['delivery_date'] ?? 4 ] ?? '',
				)
			);
			if ( $order->get_status() !== 'saina-delivered' ) {
				$order->update_status( 'completed' );
			}
		}
		fclose( $handle );
		wp_safe_redirect( admin_url( 'admin.php?page=saina-track-import&ok=1' ) );
		exit;
	}
}
