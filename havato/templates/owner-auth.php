<?php
/**
 * Café owner sign-in / sign-up screen.
 *
 * @package Havato
 *
 * @var string $lang Active language.
 */

defined( 'ABSPATH' ) || exit;

$havato_dir = Havato_I18N::dir( $lang );
?>
<div class="hv-owner-auth hv-dir-<?php echo esc_attr( $havato_dir ); ?>"
	id="havato-owner-auth"
	dir="<?php echo esc_attr( $havato_dir ); ?>">

	<div class="hv-orb hv-orb-1" aria-hidden="true"></div>
	<div class="hv-orb hv-orb-2" aria-hidden="true"></div>

	<?php include HAVATO_PATH . 'templates/parts/icons.php'; ?>

	<div class="hv-auth-card hv-glass">
		<div class="hv-auth-logo"><svg aria-hidden="true"><use href="#hv-i-cup"></use></svg></div>

		<h2 class="hv-auth-title"><?php echo esc_html( Havato_I18N::t( 'owner_login_title' ) ); ?></h2>

		<!-- Sign in / sign up switch -->
		<div class="hv-subtabs" role="tablist">
			<button type="button" class="hv-subtab is-active" data-authtab="login">
				<?php echo esc_html( Havato_I18N::t( 'owner_signin' ) ); ?>
			</button>
			<button type="button" class="hv-subtab" data-authtab="register">
				<?php echo esc_html( Havato_I18N::t( 'owner_signup' ) ); ?>
			</button>
		</div>

		<div id="hv-auth-msg" class="hv-alert" hidden></div>

		<!-- ============================ SIGN IN ============================ -->
		<form id="hv-auth-login" class="hv-auth-form">
			<div class="hv-field">
				<label for="hv-l-email"><?php echo esc_html( Havato_I18N::t( 'email' ) ); ?></label>
				<input type="email" class="hv-input" id="hv-l-email" autocomplete="username" required>
			</div>
			<div class="hv-field hv-mt">
				<label for="hv-l-pass"><?php echo esc_html( Havato_I18N::t( 'password' ) ); ?></label>
				<input type="password" class="hv-input" id="hv-l-pass" autocomplete="current-password" required>
			</div>
			<button type="submit" class="hv-btn hv-btn-blue hv-btn-block hv-mt">
				<?php echo esc_html( Havato_I18N::t( 'owner_signin' ) ); ?>
			</button>
			<p class="hv-auth-small">
				<a href="<?php echo esc_url( wp_lostpassword_url() ); ?>">
					<?php echo esc_html( Havato_I18N::t( 'forgot_password' ) ); ?>
				</a>
			</p>
		</form>

		<!-- ============================ SIGN UP ============================ -->
		<form id="hv-auth-register" class="hv-auth-form" hidden>
			<div class="hv-field">
				<label for="hv-r-venue"><?php echo esc_html( Havato_I18N::t( 'venue_name' ) ); ?></label>
				<input type="text" class="hv-input" id="hv-r-venue" required>
			</div>
			<div class="hv-field hv-mt">
				<label for="hv-r-manager"><?php echo esc_html( Havato_I18N::t( 'manager_name' ) ); ?></label>
				<input type="text" class="hv-input" id="hv-r-manager" required>
			</div>

			<div class="hv-field hv-mt">
				<label for="hv-r-country"><?php echo esc_html( Havato_I18N::t( 'q_country' ) ); ?></label>
				<select class="hv-select" id="hv-r-country"></select>
			</div>
			<div class="hv-field hv-mt">
				<label for="hv-r-city"><?php echo esc_html( Havato_I18N::t( 'q_city_select' ) ); ?></label>
				<select class="hv-select" id="hv-r-city"></select>
			</div>

			<div class="hv-field hv-mt">
				<label for="hv-r-address"><?php echo esc_html( Havato_I18N::t( 'venue_address' ) ); ?></label>
				<textarea class="hv-textarea" id="hv-r-address" rows="2"></textarea>
			</div>

			<div class="hv-field hv-mt">
				<label for="hv-r-email"><?php echo esc_html( Havato_I18N::t( 'email' ) ); ?></label>
				<input type="email" class="hv-input" id="hv-r-email" autocomplete="email" required>
			</div>
			<div class="hv-field hv-mt">
				<label for="hv-r-pass"><?php echo esc_html( Havato_I18N::t( 'password' ) ); ?></label>
				<input type="password" class="hv-input" id="hv-r-pass" autocomplete="new-password" minlength="6" required>
			</div>

			<button type="submit" class="hv-btn hv-btn-green hv-btn-block hv-mt">
				<?php echo esc_html( Havato_I18N::t( 'owner_signup' ) ); ?>
			</button>
			<p class="hv-auth-small"><?php echo esc_html( Havato_I18N::t( 'signup_pending_hint' ) ); ?></p>
		</form>
	</div>
</div>
