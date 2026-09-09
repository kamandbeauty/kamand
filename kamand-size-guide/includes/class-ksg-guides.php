<?php
/**
 * نوع نوشتهٔ «راهنمای سایز»، ویرایشگر جدول و پاک‌سازی داده‌ها.
 *
 * @package KamandSizeGuide
 */

defined( 'ABSPATH' ) || exit;

/**
 * مدیریت راهنماهای سایز.
 */
class KSG_Guides {

	const POST_TYPE   = 'ksg_size_guide';
	const META_KEY    = '_ksg_table';
	const MAX_COLUMNS = 12;
	const MAX_ROWS    = 80;
	const MAX_TIPS    = 12;

	/**
	 * نسخهٔ یکتا.
	 *
	 * @var KSG_Guides|null
	 */
	private static $instance = null;

	/**
	 * دریافت نسخهٔ یکتا.
	 *
	 * @return KSG_Guides
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
		add_action( 'init', array( __CLASS__, 'register_post_type' ) );
		add_action( 'add_meta_boxes', array( $this, 'add_meta_boxes' ) );
		add_action( 'save_post_' . self::POST_TYPE, array( $this, 'save' ), 10, 2 );
		add_action( 'admin_enqueue_scripts', array( $this, 'admin_assets' ) );
		add_filter( 'manage_' . self::POST_TYPE . '_posts_columns', array( $this, 'list_columns' ) );
		add_action( 'manage_' . self::POST_TYPE . '_posts_custom_column', array( $this, 'list_column_content' ), 10, 2 );
	}

	/**
	 * ثبت نوع نوشتهٔ راهنمای سایز.
	 *
	 * @return void
	 */
	public static function register_post_type() {
		register_post_type(
			self::POST_TYPE,
			array(
				'labels'          => array(
					'name'               => __( 'راهنماهای سایز', 'kamand-size-guide' ),
					'singular_name'      => __( 'راهنمای سایز', 'kamand-size-guide' ),
					'add_new'            => __( 'افزودن راهنمای تازه', 'kamand-size-guide' ),
					'add_new_item'       => __( 'افزودن راهنمای سایز تازه', 'kamand-size-guide' ),
					'edit_item'          => __( 'ویرایش راهنمای سایز', 'kamand-size-guide' ),
					'new_item'           => __( 'راهنمای سایز تازه', 'kamand-size-guide' ),
					'view_item'          => __( 'دیدن راهنما', 'kamand-size-guide' ),
					'search_items'       => __( 'جست‌وجوی راهنما', 'kamand-size-guide' ),
					'not_found'          => __( 'راهنمایی یافت نشد.', 'kamand-size-guide' ),
					'not_found_in_trash' => __( 'راهنمایی در زباله‌دان نیست.', 'kamand-size-guide' ),
					'menu_name'          => __( 'راهنمای سایز', 'kamand-size-guide' ),
				),
				'public'          => false,
				'show_ui'         => true,
				'show_in_menu'    => true,
				'show_in_rest'    => false,
				'menu_position'   => 56,
				'menu_icon'       => 'dashicons-editor-table',
				'capability_type' => 'post',
				'supports'        => array( 'title' ),
				'rewrite'         => false,
				'query_var'       => false,
				'has_archive'     => false,
			)
		);
	}

	/**
	 * ثبت متاباکس ویرایشگر جدول.
	 *
	 * @return void
	 */
	public function add_meta_boxes() {
		add_meta_box(
			'ksg-table-editor',
			__( 'جدول راهنمای سایز', 'kamand-size-guide' ),
			array( $this, 'render_editor' ),
			self::POST_TYPE,
			'normal',
			'high'
		);
	}

	/**
	 * بارگذاری اسکریپت‌های بخش مدیریت.
	 *
	 * @param string $hook_suffix صفحهٔ جاری پیشخوان.
	 * @return void
	 */
	public function admin_assets( $hook_suffix = '' ) {
		$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;

		$is_guide_screen = $screen && self::POST_TYPE === $screen->post_type;
		$is_product_page = $screen && 'product' === $screen->post_type;

		if ( ! $is_guide_screen && ! $is_product_page ) {
			return;
		}

		wp_enqueue_style( 'ksg-admin', KSG_PLUGIN_URL . 'assets/css/admin.css', array(), KSG_VERSION );
		wp_enqueue_media();

		wp_enqueue_script( 'ksg-admin', KSG_PLUGIN_URL . 'assets/js/admin.js', array(), KSG_VERSION, true );
		wp_localize_script(
			'ksg-admin',
			'ksgAdmin',
			array(
				'i18n'      => array(
					'columnLabel'   => __( 'عنوان ستون', 'kamand-size-guide' ),
					'kindSize'      => __( 'سایز', 'kamand-size-guide' ),
					'kindMeasure'   => __( 'عدد اندازه‌گیری', 'kamand-size-guide' ),
					'kindNote'      => __( 'توضیح', 'kamand-size-guide' ),
					'addColumn'     => __( 'افزودن ستون', 'kamand-size-guide' ),
					'addRow'        => __( 'افزودن ردیف', 'kamand-size-guide' ),
					'remove'        => __( 'حذف', 'kamand-size-guide' ),
					'duplicate'     => __( 'تکثیر', 'kamand-size-guide' ),
					'moveLeft'      => __( 'انتقال به راست', 'kamand-size-guide' ),
					'moveRight'     => __( 'انتقال به چپ', 'kamand-size-guide' ),
					'pasteHint'     => __( 'دادهٔ جدول را از اکسل یا گوگل‌شیت کپی و اینجا جای‌گذاری کنید.', 'kamand-size-guide' ),
					'pasteImport'   => __( 'ساخت جدول از متن', 'kamand-size-guide' ),
					'chooseImage'   => __( 'انتخاب تصویر', 'kamand-size-guide' ),
					'removeImage'   => __( 'حذف تصویر', 'kamand-size-guide' ),
					'row'           => __( 'ردیف', 'kamand-size-guide' ),
					'column'        => __( 'ستون', 'kamand-size-guide' ),
					'sizeColumnTip' => __( 'ستون «سایز» برای هایلایت خودکار سایز انتخاب‌شده استفاده می‌شود.', 'kamand-size-guide' ),
					'needSizeCol'   => __( 'دست‌کم یک ستون از نوع «سایز» لازم است.', 'kamand-size-guide' ),
					'emptyTable'    => __( 'جدول خالی است؛ با «افزودن ردیف» شروع کنید.', 'kamand-size-guide' ),
				),
				'maxRows'   => self::MAX_ROWS,
				'maxCols'   => self::MAX_COLUMNS,
				'maxTips'   => self::MAX_TIPS,
			)
		);
	}

	/**
	 * ساختار خالی یک جدول.
	 *
	 * @return array
	 */
	public static function empty_table() {
		return array(
			'unit'    => 'cm',
			'columns' => array(),
			'rows'    => array(),
			'tips'    => array(),
			'note'    => '',
			'image'   => 0,
		);
	}

	/**
	 * پاک‌سازی و نرمال‌سازی دادهٔ جدول.
	 *
	 * @param mixed $raw دادهٔ خام.
	 * @return array
	 */
	public static function sanitize_table( $raw ) {
		$table = self::empty_table();

		if ( is_string( $raw ) && '' !== trim( $raw ) ) {
			$decoded = json_decode( $raw, true );
			$raw     = is_array( $decoded ) ? $decoded : array();
		}

		if ( ! is_array( $raw ) ) {
			return $table;
		}

		$unit          = isset( $raw['unit'] ) ? (string) $raw['unit'] : 'cm';
		$table['unit'] = in_array( $unit, array( 'cm', 'inch' ), true ) ? $unit : 'cm';

		$columns    = isset( $raw['columns'] ) && is_array( $raw['columns'] ) ? $raw['columns'] : array();
		$used_ids   = array();
		$clean_cols = array();
		$aliases    = array();

		foreach ( $columns as $index => $column ) {
			if ( count( $clean_cols ) >= self::MAX_COLUMNS ) {
				break;
			}

			if ( ! is_array( $column ) ) {
				continue;
			}

			$label = isset( $column['label'] ) ? sanitize_text_field( (string) $column['label'] ) : '';
			$label = mb_substr( $label, 0, 40 );

			if ( '' === $label ) {
				/* translators: %d: شمارهٔ ستون */
				$label = sprintf( __( 'ستون %d', 'kamand-size-guide' ), count( $clean_cols ) + 1 );
			}

			$kind = isset( $column['kind'] ) ? (string) $column['kind'] : 'measure';
			if ( ! in_array( $kind, array( 'size', 'measure', 'note' ), true ) ) {
				$kind = 'measure';
			}

			$id          = isset( $column['id'] ) ? sanitize_key( (string) $column['id'] ) : '';
			$original_id = $id;

			if ( '' === $id || isset( $used_ids[ $id ] ) ) {
				$id = 'c' . ( $index + 1 ) . '_' . substr( md5( uniqid( (string) wp_rand(), true ) ), 0, 6 );
			}
			$used_ids[ $id ] = true;

			// کلیدهایی که مقدار همین ستون ممکن است با آن‌ها در ردیف‌ها آمده باشد.
			$aliases[ $id ] = array();
			if ( '' !== $original_id ) {
				$aliases[ $id ][] = $original_id;
			}
			$aliases[ $id ][] = (string) $index;

			$clean_cols[] = array(
				'id'    => $id,
				'label' => $label,
				'kind'  => $kind,
			);
		}

		$table['columns'] = $clean_cols;

		// تضمین وجود یک ستون «سایز» برای هایلایت خودکار.
		if ( array() !== $clean_cols && ! self::table_has_size_column( $clean_cols ) ) {
			$table['columns'][0]['kind'] = 'size';
		}

		$rows      = isset( $raw['rows'] ) && is_array( $raw['rows'] ) ? $raw['rows'] : array();
		$clean_row = array();

		foreach ( $rows as $row_index => $row ) {
			if ( count( $clean_row ) >= self::MAX_ROWS ) {
				break;
			}

			if ( ! is_array( $row ) ) {
				continue;
			}

			$values = isset( $row['values'] ) && is_array( $row['values'] ) ? $row['values'] : array();

			// پشتیبانی از ردیف‌هایی که خودشان فهرست مقادیرند (مثلاً ورودی CSV یا REST).
			if ( array() === $values && is_array( $row ) ) {
				$values = array_diff_key( array_filter( $row, 'is_scalar' ), array( 'id' => true ) );
			}

			$clean_values = array();
			$has_content  = false;

			foreach ( $clean_cols as $column ) {
				$keys  = isset( $aliases[ $column['id'] ] ) ? $aliases[ $column['id'] ] : array( $column['id'] );
				$value = sanitize_text_field( self::pick_cell_value( $values, $keys ) );
				$value = mb_substr( $value, 0, 60 );

				if ( '' !== $value ) {
					$has_content = true;
				}

				$clean_values[ $column['id'] ] = $value;
			}

			if ( ! $has_content ) {
				continue;
			}

			$row_id = isset( $row['id'] ) ? sanitize_key( (string) $row['id'] ) : '';
			if ( '' === $row_id ) {
				$row_id = 'r' . ( $row_index + 1 ) . '_' . substr( md5( uniqid( (string) wp_rand(), true ) ), 0, 6 );
			}

			$clean_row[] = array(
				'id'     => $row_id,
				'values' => $clean_values,
			);
		}

		$table['rows'] = $clean_row;

		$tips       = isset( $raw['tips'] ) && is_array( $raw['tips'] ) ? $raw['tips'] : array();
		$clean_tips = array();
		foreach ( $tips as $tip ) {
			if ( count( $clean_tips ) >= self::MAX_TIPS ) {
				break;
			}

			$tip = sanitize_text_field( (string) $tip );
			if ( '' === $tip ) {
				continue;
			}

			$clean_tips[] = mb_substr( $tip, 0, 160 );
		}
		$table['tips'] = $clean_tips;

		$table['note']  = isset( $raw['note'] ) ? mb_substr( sanitize_textarea_field( (string) $raw['note'] ), 0, 500 ) : '';
		$table['image'] = isset( $raw['image'] ) ? absint( $raw['image'] ) : 0;

		return $table;
	}

	/**
	 * یافتن مقدار یک سلول بر پایهٔ کلیدهای ممکن (شناسهٔ اصلی ستون یا جایگاه آن).
	 *
	 * @param array $values مقادیر ردیف.
	 * @param array $keys   کلیدهای قابل قبول.
	 * @return string
	 */
	public static function pick_cell_value( $values, $keys ) {
		if ( ! is_array( $values ) ) {
			return '';
		}

		foreach ( (array) $keys as $key ) {
			if ( isset( $values[ $key ] ) && '' !== (string) $values[ $key ] ) {
				return (string) $values[ $key ];
			}
		}

		return '';
	}

	/**
	 * آیا ستون‌های جدول شامل ستون «سایز» هستند؟
	 *
	 * @param array $columns ستون‌ها.
	 * @return bool
	 */
	public static function table_has_size_column( $columns ) {
		foreach ( (array) $columns as $column ) {
			if ( isset( $column['kind'] ) && 'size' === $column['kind'] ) {
				return true;
			}
		}

		return false;
	}

	/**
	 * آیا جدول قابل نمایش است؟
	 *
	 * @param array $table جدول.
	 * @return bool
	 */
	public static function table_is_valid( $table ) {
		return is_array( $table )
			&& ! empty( $table['columns'] )
			&& ! empty( $table['rows'] );
	}

	/**
	 * خواندن جدول یک راهنما همراه با مقدار پیش‌فرض.
	 *
	 * @param int $guide_id شناسهٔ راهنما.
	 * @return array
	 */
	public static function get_table( $guide_id ) {
		$guide_id = absint( $guide_id );

		if ( ! $guide_id ) {
			return self::empty_table();
		}

		$table = get_post_meta( $guide_id, self::META_KEY, true );

		if ( ! is_array( $table ) ) {
			return self::empty_table();
		}

		return wp_parse_args( $table, self::empty_table() );
	}

	/**
	 * عنوان یک راهنما.
	 *
	 * @param int $guide_id شناسهٔ راهنما.
	 * @return string
	 */
	public static function get_title( $guide_id ) {
		$title = get_the_title( absint( $guide_id ) );

		return $title ? $title : __( 'راهنمای سایز', 'kamand-size-guide' );
	}

	/**
	 * فهرست راهنماهای منتشرشده برای انتخاب.
	 *
	 * @return array<int,string>
	 */
	public static function get_choices() {
		$posts = get_posts(
			array(
				'post_type'      => self::POST_TYPE,
				'post_status'    => 'publish',
				'posts_per_page' => 100,
				'orderby'        => 'title',
				'order'          => 'ASC',
				'no_found_rows'  => true,
			)
		);

		$choices = array();
		foreach ( $posts as $post ) {
			$choices[ (int) $post->ID ] = $post->post_title;
		}

		return $choices;
	}

	/**
	 * ساخت یک راهنمای نمونه.
	 *
	 * @param string $title عنوان راهنما.
	 * @return int شناسهٔ نوشتهٔ ساخته‌شده یا صفر.
	 */
	public static function create_sample( $title = '' ) {
		$title = $title ? $title : __( 'راهنمای سایز پوشاک (نمونه)', 'kamand-size-guide' );

		$post_id = wp_insert_post(
			array(
				'post_type'   => self::POST_TYPE,
				'post_status' => 'publish',
				'post_title'  => $title,
			),
			true
		);

		if ( ! $post_id || is_wp_error( $post_id ) ) {
			return 0;
		}

		update_post_meta(
			$post_id,
			self::META_KEY,
			array(
				'unit'    => 'cm',
				'columns' => array(
					array( 'id' => 'c_size', 'label' => __( 'سایز', 'kamand-size-guide' ), 'kind' => 'size' ),
					array( 'id' => 'c_bust', 'label' => __( 'دور سینه', 'kamand-size-guide' ), 'kind' => 'measure' ),
					array( 'id' => 'c_waist', 'label' => __( 'دور کمر', 'kamand-size-guide' ), 'kind' => 'measure' ),
					array( 'id' => 'c_hip', 'label' => __( 'دور باسن', 'kamand-size-guide' ), 'kind' => 'measure' ),
					array( 'id' => 'c_note', 'label' => __( 'مناسب برای', 'kamand-size-guide' ), 'kind' => 'note' ),
				),
				'rows'    => array(
					array( 'id' => 'r_s', 'values' => array( 'c_size' => 'S', 'c_bust' => '86', 'c_waist' => '68', 'c_hip' => '92', 'c_note' => __( '۳۶ ایران', 'kamand-size-guide' ) ) ),
					array( 'id' => 'r_m', 'values' => array( 'c_size' => 'M', 'c_bust' => '92', 'c_waist' => '74', 'c_hip' => '98', 'c_note' => __( '۳۸ ایران', 'kamand-size-guide' ) ) ),
					array( 'id' => 'r_l', 'values' => array( 'c_size' => 'L', 'c_bust' => '98', 'c_waist' => '80', 'c_hip' => '104', 'c_note' => __( '۴۰ ایران', 'kamand-size-guide' ) ) ),
					array( 'id' => 'r_xl', 'values' => array( 'c_size' => 'XL', 'c_bust' => '104', 'c_waist' => '86', 'c_hip' => '110', 'c_note' => __( '۴۲ ایران', 'kamand-size-guide' ) ) ),
				),
				'tips'    => array(
					__( 'اندازه‌ها با خط‌کش نرم و روی بدن بدون لباس ضخیم گرفته شده‌اند.', 'kamand-size-guide' ),
					__( 'اگر بین دو سایز هستید، سایز بزرگ‌تر را انتخاب کنید.', 'kamand-size-guide' ),
				),
				'note'    => __( 'تلورانس دوخت این کار تا ۲ سانتی‌متر است.', 'kamand-size-guide' ),
				'image'   => 0,
			)
		);

		return (int) $post_id;
	}

	/**
	 * رندر ویرایشگر جدول، نکته‌ها و تصویر در صفحهٔ راهنما.
	 *
	 * @param WP_Post $post نوشتهٔ جاری.
	 * @return void
	 */
	public function render_editor( $post ) {
		$table = wp_parse_args( get_post_meta( $post->ID, self::META_KEY, true ), self::empty_table() );

		wp_nonce_field( 'ksg_save_guide', 'ksg_guide_nonce' );

		echo '<div class="ksg-admin" data-ksg-editor="guide">';

		printf(
			'<script type="application/json" class="ksg-admin-data">%s</script>',
			wp_json_encode(
				array(
					'table'   => $table,
					'prefix'  => 'ksg_table',
					'context' => 'guide',
				)
			)
		);

		echo '<div class="ksg-admin-shell"></div>';
		echo '<input type="hidden" name="ksg_table" class="ksg-admin-json" value="" />';
		echo '<p class="description">' . esc_html__( 'ستون اول بهتر است از نوع «سایز» باشد تا هنگام انتخاب سایز در محصولات متغیر، ردیف مناسب به‌صورت خودکار برجسته شود. ستون‌های «عدد اندازه‌گیری» با کلید سانتی‌متر/اینچ در فروشگاه تبدیل می‌شوند.', 'kamand-size-guide' ) . '</p>';
		echo '</div>';
	}

	/**
	 * ذخیرهٔ دادهٔ جدول هنگام ذخیرهٔ راهنما.
	 *
	 * @param int     $post_id شناسهٔ نوشته.
	 * @param WP_Post $post    شیء نوشته.
	 * @return void
	 */
	public function save( $post_id, $post = null ) {
		if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
			return;
		}

		if ( ! isset( $_POST['ksg_guide_nonce'] ) || ! wp_verify_nonce( sanitize_key( wp_unslash( $_POST['ksg_guide_nonce'] ) ), 'ksg_save_guide' ) ) {
			return;
		}

		if ( ! current_user_can( 'edit_post', $post_id ) ) {
			return;
		}

		$raw = isset( $_POST['ksg_table'] ) ? wp_unslash( $_POST['ksg_table'] ) : ''; // phpcs:ignore WordPress.Security.ValidatedSanitizedInput -- در sanitize_table پاک‌سازی می‌شود.

		update_post_meta( $post_id, self::META_KEY, self::sanitize_table( $raw ) );
	}

	/**
	 * ستون‌های فهرست راهنماها.
	 *
	 * @param array $columns ستون‌های موجود.
	 * @return array
	 */
	public function list_columns( $columns ) {
		$columns['ksg_size']  = __( 'اندازهٔ جدول', 'kamand-size-guide' );
		$columns['ksg_unit']  = __( 'واحد', 'kamand-size-guide' );
		$columns['ksg_usage'] = __( 'محل استفاده', 'kamand-size-guide' );

		return $columns;
	}

	/**
	 * محتوای ستون‌های سفارشی فهرست راهنماها.
	 *
	 * @param string $column  نام ستون.
	 * @param int    $post_id شناسهٔ نوشته.
	 * @return void
	 */
	public function list_column_content( $column, $post_id ) {
		$table = self::get_table( $post_id );

		if ( 'ksg_size' === $column ) {
			printf(
				/* translators: 1: تعداد ردیف، 2: تعداد ستون */
				esc_html__( '%1$d ردیف × %2$d ستون', 'kamand-size-guide' ),
				count( $table['rows'] ),
				count( $table['columns'] )
			);
		}

		if ( 'ksg_unit' === $column ) {
			echo esc_html( 'inch' === $table['unit'] ? __( 'اینچ', 'kamand-size-guide' ) : __( 'سانتی‌متر', 'kamand-size-guide' ) );
		}

		if ( 'ksg_usage' === $column ) {
			echo esc_html( KSG_Products::count_usage( $post_id ) );
		}
	}
}
