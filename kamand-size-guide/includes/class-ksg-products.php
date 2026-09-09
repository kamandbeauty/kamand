<?php
/**
 * اختصاص راهنمای سایز به محصول و دسته‌بندی و تشخیص راهنمای نهایی هر محصول.
 *
 * @package KamandSizeGuide
 */

defined( 'ABSPATH' ) || exit;

/**
 * مدیریت ارتباط محصول و راهنمای سایز.
 */
class KSG_Products {

	const META_MODE     = '_ksg_mode';
	const META_GUIDES   = '_ksg_guide_ids';
	const META_INLINE   = '_ksg_inline_table';
	const TERM_META_KEY = 'ksg_guide_id';

	/**
	 * نسخهٔ یکتا.
	 *
	 * @var KSG_Products|null
	 */
	private static $instance = null;

	/**
	 * دریافت نسخهٔ یکتا.
	 *
	 * @return KSG_Products
	 */
	public static function instance() {
		if ( null === self::$instance ) {
			self::$instance = new self();
		}

		return self::$instance;
	}

	/**
	 * ثبت هوک‌ها.
	 */
	private function __construct() {
		add_action( 'add_meta_boxes', array( $this, 'add_meta_boxes' ) );
		add_action( 'save_post_product', array( $this, 'save' ), 10, 2 );
		add_action( 'product_cat_add_form_fields', array( $this, 'category_field_add' ), 20 );
		add_action( 'product_cat_edit_form_fields', array( $this, 'category_field_edit' ), 20 );
		add_action( 'created_product_cat', array( $this, 'save_category_field' ) );
		add_action( 'edited_product_cat', array( $this, 'save_category_field' ) );
	}

	/**
	 * ثبت متاباکس محصول.
	 *
	 * @return void
	 */
	public function add_meta_boxes() {
		add_meta_box(
			'ksg-product-box',
			__( 'راهنمای سایز (کمند)', 'kamand-size-guide' ),
			array( $this, 'render_meta_box' ),
			'product',
			'normal',
			'high'
		);
	}

	/**
	 * رندر متاباکس محصول.
	 *
	 * @param WP_Post $post نوشتهٔ جاری.
	 * @return void
	 */
	public function render_meta_box( $post ) {
		$mode    = (string) get_post_meta( $post->ID, self::META_MODE, true );
		$mode    = in_array( $mode, array( 'inherit', 'custom', 'none' ), true ) ? $mode : 'inherit';
		$guides  = array_map( 'absint', (array) get_post_meta( $post->ID, self::META_GUIDES, true ) );
		$inline  = wp_parse_args( get_post_meta( $post->ID, self::META_INLINE, true ), KSG_Guides::empty_table() );
		$choices = KSG_Guides::get_choices();

		wp_nonce_field( 'ksg_save_product', 'ksg_product_nonce' );

		echo '<div class="ksg-admin" data-ksg-product="1">';

		echo '<p class="ksg-field">';
		foreach ( array(
			'inherit' => __( 'ارث‌بری (دسته‌بندی یا راهنمای پیش‌فرض فروشگاه)', 'kamand-size-guide' ),
			'custom'  => __( 'راهنمای اختصاصی همین محصول', 'kamand-size-guide' ),
			'none'    => __( 'بدون راهنمای سایز', 'kamand-size-guide' ),
		) as $value => $label ) {
			printf(
				'<label class="ksg-radio"><input type="radio" name="ksg_mode" value="%1$s" %2$s /> <span>%3$s</span></label>',
				esc_attr( $value ),
				checked( $mode, $value, false ),
				esc_html( $label )
			);
		}
		echo '</p>';

		echo '<div class="ksg-mode-panel" data-ksg-mode="custom">';

		echo '<p class="ksg-field"><strong>' . esc_html__( 'انتخاب از راهنماهای آماده', 'kamand-size-guide' ) . '</strong></p>';

		if ( array() === $choices ) {
			printf(
				'<p class="description">%s</p>',
				sprintf(
					/* translators: %s: مسیر منوی راهنمای سایز */
					esc_html__( 'هنوز راهنمایی نساخته‌اید. از منوی «راهنمای سایز» در پیشخوان یک راهنما بسازید یا از جدول اختصاصی زیر استفاده کنید.', 'kamand-size-guide' ),
					esc_html( 'راهنمای سایز' )
				)
			);
		} else {
			echo '<div class="ksg-checklist">';
			foreach ( $choices as $id => $title ) {
				printf(
					'<label class="ksg-radio"><input type="checkbox" name="ksg_guide_ids[]" value="%1$d" %2$s /> <span>%3$s</span></label>',
					esc_attr( $id ),
					checked( in_array( (int) $id, $guides, true ), true, false ),
					esc_html( $title )
				);
			}
			echo '</div>';
			echo '<p class="description">' . esc_html__( 'اگر بیش از یک راهنما انتخاب کنید، در فروشگاه به‌صورت تب نمایش داده می‌شوند.', 'kamand-size-guide' ) . '</p>';
		}

		echo '<hr class="ksg-sep" />';

		echo '<p class="ksg-field"><strong>' . esc_html__( 'جدول اختصاصی همین محصول', 'kamand-size-guide' ) . '</strong></p>';

		printf(
			'<script type="application/json" class="ksg-admin-data">%s</script>',
			wp_json_encode(
				array(
					'table'   => $inline,
					'prefix'  => 'ksg_table',
					'context' => 'product',
				)
			)
		);
		echo '<div class="ksg-admin-shell" data-ksg-editor="product"></div>';
		echo '<input type="hidden" name="ksg_table" class="ksg-admin-json" value="" />';
		echo '<p class="description">' . esc_html__( 'اگر راهنمای آماده انتخاب نکرده باشید، این جدول زیر دکمهٔ خرید نمایش داده می‌شود.', 'kamand-size-guide' ) . '</p>';

		echo '</div>';

		echo '<div class="ksg-mode-panel" data-ksg-mode="inherit">';
		$resolved = self::resolve_from_inheritance( $post->ID );
		if ( array() === $resolved ) {
			echo '<p class="description">' . esc_html__( 'در حال حاضر برای دسته‌بندی این محصول یا فروشگاه، راهنمای پیش‌فرضی تنظیم نشده است؛ می‌توانید در «تنظیمات › راهنمای سایز» یا فرم ویرایش دسته‌بندی محصول یک راهنمای پیش‌فرض تعیین کنید.', 'kamand-size-guide' ) . '</p>';
		} else {
			$names = wp_list_pluck( $resolved, 'title' );
			printf(
				'<p class="description">%s <strong>%s</strong></p>',
				esc_html__( 'راهنمای نمایش‌داده‌شده:', 'kamand-size-guide' ),
				esc_html( implode( '، ', $names ) )
			);
		}
		echo '</div>';

		echo '<div class="ksg-mode-panel" data-ksg-mode="none">';
		echo '<p class="description">' . esc_html__( 'برای این محصول هیچ جدول راهنمای سایزی نمایش داده نمی‌شود.', 'kamand-size-guide' ) . '</p>';
		echo '</div>';

		echo '</div>';
	}

	/**
	 * ذخیرهٔ داده‌های محصول.
	 *
	 * @param int     $post_id شناسهٔ محصول.
	 * @param WP_Post $post    شیء نوشته.
	 * @return void
	 */
	public function save( $post_id, $post = null ) {
		if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
			return;
		}

		if ( ! isset( $_POST['ksg_product_nonce'] ) || ! wp_verify_nonce( sanitize_key( wp_unslash( $_POST['ksg_product_nonce'] ) ), 'ksg_save_product' ) ) {
			return;
		}

		if ( ! current_user_can( 'edit_product', $post_id ) ) {
			return;
		}

		$mode = isset( $_POST['ksg_mode'] ) ? sanitize_key( wp_unslash( $_POST['ksg_mode'] ) ) : 'inherit';
		if ( ! in_array( $mode, array( 'inherit', 'custom', 'none' ), true ) ) {
			$mode = 'inherit';
		}
		update_post_meta( $post_id, self::META_MODE, $mode );

		$guide_ids = array();
		if ( isset( $_POST['ksg_guide_ids'] ) && is_array( $_POST['ksg_guide_ids'] ) ) {
			$guide_ids = array_values( array_unique( array_filter( array_map( 'absint', wp_unslash( $_POST['ksg_guide_ids'] ) ) ) ) ); // phpcs:ignore WordPress.Security.ValidatedSanitizedInput -- فقط عدد صحیح نگه داشته می‌شود.
		}
		update_post_meta( $post_id, self::META_GUIDES, $guide_ids );

		$raw = isset( $_POST['ksg_table'] ) ? wp_unslash( $_POST['ksg_table'] ) : ''; // phpcs:ignore WordPress.Security.ValidatedSanitizedInput -- در sanitize_table پاک‌سازی می‌شود.
		update_post_meta( $post_id, self::META_INLINE, KSG_Guides::sanitize_table( $raw ) );
	}

	/**
	 * فیلد انتخاب راهنما در فرم افزودن دسته‌بندی.
	 *
	 * @return void
	 */
	public function category_field_add() {
		$choices = KSG_Guides::get_choices();
		wp_nonce_field( 'ksg_save_term', 'ksg_term_nonce' );

		echo '<div class="form-field term-ksg-wrap">';
		echo '<label for="ksg_term_guide">' . esc_html__( 'راهنمای سایز پیش‌فرض', 'kamand-size-guide' ) . '</label>';
		echo self::guide_select_html( 0, $choices ); // phpcs:ignore WordPress.Security.EscapeOutput -- خروجی درون متد escape شده است.
		echo '<p class="description">' . esc_html__( 'این راهنما برای همهٔ محصولات همین دسته (و زیردسته‌ها) که راهنمای اختصاصی ندارند نمایش داده می‌شود.', 'kamand-size-guide' ) . '</p>';
		echo '</div>';
	}

	/**
	 * فیلد انتخاب راهنما در فرم ویرایش دسته‌بندی.
	 *
	 * @param WP_Term $term دستهٔ جاری.
	 * @return void
	 */
	public function category_field_edit( $term ) {
		$current = (int) get_term_meta( $term->term_id, self::TERM_META_KEY, true );
		$choices = KSG_Guides::get_choices();
		wp_nonce_field( 'ksg_save_term', 'ksg_term_nonce' );

		echo '<tr class="form-field term-ksg-wrap">';
		echo '<th scope="row"><label for="ksg_term_guide">' . esc_html__( 'راهنمای سایز پیش‌فرض', 'kamand-size-guide' ) . '</label></th>';
		echo '<td>';
		echo self::guide_select_html( $current, $choices ); // phpcs:ignore WordPress.Security.EscapeOutput -- خروجی درون متد escape شده است.
		echo '<p class="description">' . esc_html__( 'این راهنما برای همهٔ محصولات همین دسته (و زیردسته‌ها) که راهنمای اختصاصی ندارند نمایش داده می‌شود.', 'kamand-size-guide' ) . '</p>';
		echo '</td></tr>';
	}

	/**
	 * ساخت HTML انتخاب راهنما.
	 *
	 * @param int   $current شناسهٔ انتخاب‌شده.
	 * @param array $choices فهرست راهنماها.
	 * @return string
	 */
	private static function guide_select_html( $current, $choices ) {
		$html  = '<select name="ksg_term_guide" id="ksg_term_guide">';
		$html .= '<option value="0">' . esc_html__( '— بدون راهنمای پیش‌فرض —', 'kamand-size-guide' ) . '</option>';

		foreach ( $choices as $id => $title ) {
			$html .= sprintf(
				'<option value="%1$d" %2$s>%3$s</option>',
				esc_attr( $id ),
				selected( (int) $current, (int) $id, false ),
				esc_html( $title )
			);
		}

		$html .= '</select>';

		return $html;
	}

	/**
	 * ذخیرهٔ راهنمای پیش‌فرض دسته.
	 *
	 * @param int $term_id شناسهٔ دسته.
	 * @return void
	 */
	public function save_category_field( $term_id ) {
		if ( ! isset( $_POST['ksg_term_nonce'] ) || ! wp_verify_nonce( sanitize_key( wp_unslash( $_POST['ksg_term_nonce'] ) ), 'ksg_save_term' ) ) {
			return;
		}

		$guide_id = isset( $_POST['ksg_term_guide'] ) ? absint( $_POST['ksg_term_guide'] ) : 0;

		if ( $guide_id ) {
			update_term_meta( $term_id, self::TERM_META_KEY, $guide_id );
		} else {
			delete_term_meta( $term_id, self::TERM_META_KEY );
		}
	}

	/**
	 * تشخیص راهنمای نمایش‌داده‌شده برای یک محصول.
	 *
	 * @param int $product_id شناسهٔ محصول.
	 * @return array<int,array{id:int,title:string,table:array}>
	 */
	public static function resolve_guides( $product_id ) {
		$product_id = absint( $product_id );

		if ( ! $product_id ) {
			return array();
		}

		$mode = (string) get_post_meta( $product_id, self::META_MODE, true );
		$mode = in_array( $mode, array( 'inherit', 'custom', 'none' ), true ) ? $mode : 'inherit';

		if ( 'none' === $mode ) {
			return array();
		}

		$guides = array();

		if ( 'custom' === $mode ) {
			$guide_ids = array_map( 'absint', (array) get_post_meta( $product_id, self::META_GUIDES, true ) );

			foreach ( $guide_ids as $guide_id ) {
				$table = KSG_Guides::get_table( $guide_id );

				if ( ! KSG_Guides::table_is_valid( $table ) ) {
					continue;
				}

				$guides[] = array(
					'id'    => $guide_id,
					'title' => KSG_Guides::get_title( $guide_id ),
					'table' => $table,
				);
			}

			// اگر راهنمای آماده انتخاب نشده بود، جدول اختصاصی محصول استفاده می‌شود.
			if ( array() === $guides ) {
				$inline = wp_parse_args( get_post_meta( $product_id, self::META_INLINE, true ), KSG_Guides::empty_table() );

				if ( KSG_Guides::table_is_valid( $inline ) ) {
					$guides[] = array(
						'id'    => 0,
						'title' => KSG_Settings::value( 'title' ),
						'table' => $inline,
					);
				}
			}
		}

		if ( array() === $guides ) {
			$guides = self::resolve_from_inheritance( $product_id );
		}

		/**
		 * فیلتر راهنماهای نمایش‌داده‌شده برای یک محصول.
		 *
		 * @param array $guides     فهرست راهنماها.
		 * @param int   $product_id شناسهٔ محصول.
		 */
		return apply_filters( 'ksg_product_guides', $guides, $product_id );
	}

	/**
	 * تشخیص راهنما از دسته‌بندی یا تنظیمات پیش‌فرض.
	 *
	 * @param int $product_id شناسهٔ محصول.
	 * @return array
	 */
	public static function resolve_from_inheritance( $product_id ) {
		$guide_id = 0;

		if ( KSG_Settings::value( 'auto_category' ) ) {
			$guide_id = self::category_guide_id( $product_id );
		}

		if ( ! $guide_id ) {
			$guide_id = absint( KSG_Settings::value( 'default_guide_id' ) );
		}

		if ( ! $guide_id ) {
			return array();
		}

		$table = KSG_Guides::get_table( $guide_id );

		if ( ! KSG_Guides::table_is_valid( $table ) ) {
			return array();
		}

		return array(
			array(
				'id'    => $guide_id,
				'title' => KSG_Guides::get_title( $guide_id ),
				'table' => $table,
			),
		);
	}

	/**
	 * یافتن راهنمای پیش‌فرض نزدیک‌ترین دسته‌بندی محصول.
	 *
	 * @param int $product_id شناسهٔ محصول.
	 * @return int
	 */
	public static function category_guide_id( $product_id ) {
		$terms = get_the_terms( $product_id, 'product_cat' );

		if ( ! $terms || is_wp_error( $terms ) ) {
			return 0;
		}

		// دسته‌های فرزند اولویت دارند.
		usort(
			$terms,
			static function ( $a, $b ) {
				return ( (int) $b->parent <=> (int) $a->parent );
			}
		);

		foreach ( $terms as $term ) {
			$guide_id = (int) get_term_meta( (int) $term->term_id, self::TERM_META_KEY, true );

			if ( $guide_id ) {
				return $guide_id;
			}

			// پیمایش به سمت دسته‌های والد.
			$parent = (int) $term->parent;
			$guard  = 0;
			while ( $parent && $guard < 10 ) {
				$guide_id = (int) get_term_meta( $parent, self::TERM_META_KEY, true );
				if ( $guide_id ) {
					return $guide_id;
				}

				$parent_term = get_term( $parent, 'product_cat' );
				$parent      = ( $parent_term && ! is_wp_error( $parent_term ) ) ? (int) $parent_term->parent : 0;
				++$guard;
			}
		}

		return 0;
	}

	/**
	 * شمارش محصولات و دسته‌هایی که یک راهنما را استفاده می‌کنند.
	 *
	 * @param int $guide_id شناسهٔ راهنما.
	 * @return string
	 */
	public static function count_usage( $guide_id ) {
		$guide_id = absint( $guide_id );

		if ( ! $guide_id ) {
			return '—';
		}

		$global = absint( KSG_Settings::value( 'default_guide_id' ) );

		if ( $global === $guide_id ) {
			return __( 'پیش‌فرض فروشگاه', 'kamand-size-guide' );
		}

		$terms = get_terms(
			array(
				'taxonomy'   => 'product_cat',
				'hide_empty' => false,
				'fields'     => 'ids',
				'number'     => 200,
			)
		);

		$categories = 0;
		if ( is_array( $terms ) ) {
			foreach ( $terms as $term_id ) {
				if ( (int) get_term_meta( (int) $term_id, self::TERM_META_KEY, true ) === $guide_id ) {
					++$categories;
				}
			}
		}

		$products = 0;
		$meta     = get_post_meta_by_key( self::META_GUIDES );
		foreach ( (array) $meta as $row ) {
			$value = isset( $row['meta_value'] ) ? maybe_unserialize( $row['meta_value'] ) : array();
			if ( is_array( $value ) && in_array( $guide_id, array_map( 'intval', $value ), true ) ) {
				++$products;
			}
		}

		return sprintf(
			/* translators: 1: تعداد محصول، 2: تعداد دسته */
			_n( '%1$d محصول', '%1$d محصول', $products, 'kamand-size-guide' ) . ' · ' . _n( '%2$d دسته', '%2$d دسته', $categories, 'kamand-size-guide' ),
			$products,
			$categories
		);
	}
}
