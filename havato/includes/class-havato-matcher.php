<?php
/**
 * Smart Matcher Core — builds the best possible N-seat table out of a queue.
 *
 * Two execution paths (section 7):
 *   1. PRIMARY  — fires automatically the moment the last seat of an event is
 *                 taken (queue count === max_capacity). No admin button needed.
 *   2. FALLBACK — a cron job runs `cron_lead_hours` before the event and forces
 *                 the algorithm on every event that is still not matched, no
 *                 matter how few people registered (even 1 or 2). This is where
 *                 the "low-registration relaxation" actually kicks in.
 *
 * @package Havato
 */

defined( 'ABSPATH' ) || exit;

/**
 * Matching engine.
 */
class Havato_Matcher {

	/**
	 * PRIMARY PATH — called after every successful registration.
	 * Runs only when the event queue is exactly full.
	 *
	 * @param string $event_id Event id.
	 * @return array|false Result array when it ran, false otherwise.
	 */
	public static function maybe_run_on_full( $event_id ) {
		global $wpdb;
		Havato_DB::ensure_tables();

		$events = Havato_DB::table( 'events' );
		$regs   = Havato_DB::table( 'event_registrations' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$event = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $events WHERE id=%s", $event_id ), ARRAY_A );
		if ( ! $event || 'open' !== $event['status'] ) {
			return false;
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$queued = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM $regs WHERE event_id=%s AND status='queued'", $event_id ) );

		if ( $queued < (int) $event['max_capacity'] ) {
			return false;
		}

		Havato_Logger::log( sprintf( 'Last seat filled for event %s — engine armed (primary path).', $event_id ), 'info' );

		return self::run( $event_id, false );
	}

	/**
	 * Execute the matcher for one event.
	 *
	 * @param string $event_id Event id.
	 * @param bool   $relaxed  Force relaxed mode (fallback cron path).
	 * @return array{ok:bool,message:string,groups:array}
	 */
	public static function run( $event_id, $relaxed = false ) {
		global $wpdb;
		Havato_DB::ensure_tables();

		$events   = Havato_DB::table( 'events' );
		$regs     = Havato_DB::table( 'event_registrations' );
		$groups_t = Havato_DB::table( 'groups' );
		$gm_t     = Havato_DB::table( 'group_members' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$event = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM $events WHERE id=%s", $event_id ), ARRAY_A );
		if ( ! $event ) {
			return array( 'ok' => false, 'message' => 'Event not found.', 'groups' => array() );
		}
		if ( 'matched' === $event['status'] || 'completed' === $event['status'] ) {
			return array( 'ok' => false, 'message' => 'Event already matched.', 'groups' => array() );
		}

		Havato_Logger::log( sprintf( 'Matching engine activated for event %s.', $event_id ), 'success' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$rows = $wpdb->get_results( $wpdb->prepare( "SELECT user_id FROM $regs WHERE event_id=%s AND status='queued' ORDER BY id ASC", $event_id ), ARRAY_A );

		$user_ids = array_map( 'intval', wp_list_pluck( (array) $rows, 'user_id' ) );
		$user_ids = array_values( array_unique( array_filter( $user_ids ) ) );

		if ( empty( $user_ids ) ) {
			Havato_Logger::log( sprintf( 'No queued guests for event %s — nothing to seat.', $event_id ), 'warn' );
			return array( 'ok' => false, 'message' => 'Queue is empty.', 'groups' => array() );
		}

		Havato_Logger::log( sprintf( 'Region scan complete: %d guests in queue.', count( $user_ids ) ), 'info' );

		// Seat sizes come from the physical furniture the café picked for this
		// event: 3x4 + 1x6 means groups of 4, 4, 4 and 6 — NOT one group of 18.
		// Events created before tables existed fall back to max_capacity.
		$seat_plan = self::seat_plan( $event );
		$capacity  = array_sum( $seat_plan );

		// RELAXATION: when the queue can not fill a balanced table, soften every
		// secondary penalty/bonus so a table is ALWAYS produced (hard blocklist
		// constraint excluded — it is never relaxed).
		$relaxed = $relaxed || count( $user_ids ) < $capacity;
		if ( $relaxed ) {
			Havato_Logger::log( 'Low-registration mode: secondary criteria relaxed to guarantee an output table.', 'warn' );
		}

		Havato_Logger::log(
			sprintf( 'Seating plan: %d table(s) — %s seats.', count( $seat_plan ), implode( '+', $seat_plan ) ),
			'info'
		);

		$profiles = self::load_profiles( $user_ids );
		$tables   = self::build_tables( $user_ids, $profiles, $seat_plan, $relaxed );

		if ( empty( $tables ) ) {
			Havato_Logger::log( 'Engine could not seat anyone (all pairs blocked).', 'error' );
			return array( 'ok' => false, 'message' => 'No table could be formed.', 'groups' => array() );
		}

		// Persist the tables.
		$created = array();
		$index   = 1;
		foreach ( $tables as $table ) {
			$gid = havato_uid( 'g' );
			// phpcs:ignore WordPress.DB.DirectDatabaseQuery
			$wpdb->insert(
				$groups_t,
				array(
					'id'         => $gid,
					'event_id'   => $event_id,
					'name'       => sprintf( 'Table %d', $index ),
					'score'      => round( $table['score'], 2 ),
					'created_at' => havato_now(),
				),
				array( '%s', '%s', '%s', '%f', '%s' )
			);

			foreach ( $table['members'] as $uid ) {
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->insert(
					$gm_t,
					array(
						'group_id'   => $gid,
						'user_id'    => $uid,
						'created_at' => havato_now(),
					),
					array( '%s', '%d', '%s' )
				);

				// phpcs:ignore WordPress.DB.DirectDatabaseQuery
				$wpdb->update(
					$regs,
					array( 'status' => 'matched' ),
					array( 'event_id' => $event_id, 'user_id' => $uid ),
					array( '%s' ),
					array( '%s', '%d' )
				);
			}

			self::system_message( $gid, $event );

			$created[] = array(
				'id'      => $gid,
				'score'   => round( $table['score'], 2 ),
				'members' => $table['members'],
			);

			Havato_Logger::log(
				sprintf( 'Table matched successfully: %d seats, harmony score %.1f (group %s).', count( $table['members'] ), $table['score'], $gid ),
				'success'
			);
			$index++;
		}

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update( $events, array( 'status' => 'matched' ), array( 'id' => $event_id ), array( '%s' ), array( '%s' ) );

		self::bump_venue_stats( $event['venue_id'], count( $user_ids ) );

		Havato_Logger::log( sprintf( 'Notifications dispatched to %d guests for event %s.', count( $user_ids ), $event_id ), 'success' );

		do_action( 'havato_event_matched', $event_id, $created );

		return array(
			'ok'      => true,
			'message' => sprintf( '%d table(s) created.', count( $created ) ),
			'groups'  => $created,
		);
	}


	/**
	 * Expand an event's furniture into a flat list of seat counts.
	 *
	 * "3 tables of 4 + 1 table of 6" becomes [6, 4, 4, 4] — biggest first, so
	 * the strongest groups are formed while the candidate pool is deepest.
	 *
	 * @param array $event Event row.
	 * @return array List of seat counts, never empty.
	 */
	private static function seat_plan( $event ) {
		$plan = array();

		foreach ( Havato_REST::event_tables( $event['id'] ) as $row ) {
			$seats = max( 2, (int) $row['seats'] );
			for ( $i = 0; $i < max( 1, (int) $row['quantity'] ); $i++ ) {
				$plan[] = $seats;
			}
		}

		if ( empty( $plan ) ) {
			// Legacy event with no furniture attached: one table, old capacity.
			$plan[] = max( 2, (int) $event['max_capacity'] );
		}

		rsort( $plan );

		return $plan;
	}

	/**
	 * Greedy + local-search table builder.
	 *
	 * Strategy (commented per the spec):
	 *   1. Score every possible pair once (O(n^2)) using compat_score().
	 *   2. Seed a table with the highest scoring *available* pair.
	 *   3. Repeatedly add the candidate with the highest AVERAGE compatibility
	 *      against everybody already seated (+ soft gender-balance bonus), until
	 *      the table reaches capacity or the pool runs out.
	 *   4. Local search: try swapping the weakest member of the table with the
	 *      best leftover candidate while it improves the average score.
	 *   5. Repeat from (2) with the remaining pool so nobody is left behind —
	 *      leftovers always end up on a (smaller) table instead of being dropped.
	 *
	 * @param array $user_ids  Candidate user ids.
	 * @param array $profiles  user_id => profile row.
	 * @param array $seat_plan Seats of each physical table, biggest first.
	 * @param bool  $relaxed   Relaxed mode.
	 * @return array List of ['members'=>[], 'score'=>float]
	 */
	private static function build_tables( $user_ids, $profiles, $seat_plan, $relaxed ) {
		// Each pass fills the next physical table; $capacity changes per table.
		$plan     = array_values( (array) $seat_plan );
		$plan_i   = 0;
		$capacity = isset( $plan[0] ) ? (int) $plan[0] : 6;
		$pairs = array();
		$n     = count( $user_ids );

		for ( $i = 0; $i < $n; $i++ ) {
			for ( $j = $i + 1; $j < $n; $j++ ) {
				$a = $user_ids[ $i ];
				$b = $user_ids[ $j ];
				$pairs[ self::pair_key( $a, $b ) ] = self::compat_score( $profiles[ $a ], $profiles[ $b ], $relaxed );
			}
		}

		$pool   = $user_ids;
		$tables = array();
		$guard  = 0;

		while ( count( $pool ) > 0 && $guard < 50 ) {
			$guard++;

			// Move to the next table in the plan. Once the café's furniture is
			// exhausted, keep the last size so nobody is silently dropped.
			if ( isset( $plan[ $plan_i ] ) ) {
				$capacity = max( 2, (int) $plan[ $plan_i ] );
			}
			$plan_i++;

			// --- Step 2: seed with the best available pair ------------------
			$seed_score = null;
			$seed       = array();

			for ( $i = 0; $i < count( $pool ); $i++ ) {
				for ( $j = $i + 1; $j < count( $pool ); $j++ ) {
					$a  = $pool[ $i ];
					$b  = $pool[ $j ];
					$sc = isset( $pairs[ self::pair_key( $a, $b ) ] ) ? $pairs[ self::pair_key( $a, $b ) ] : null;
					if ( null === $sc ) {
						continue; // Hard blocked pair.
					}
					if ( null === $seed_score || $sc > $seed_score ) {
						$seed_score = $sc;
						$seed       = array( $a, $b );
					}
				}
			}

			if ( empty( $seed ) ) {
				// Nobody can sit together (or a single person is left):
				// seat the remaining people alone rather than dropping them.
				$table  = array( array_shift( $pool ) );
				$tables[] = array( 'members' => $table, 'score' => 0.0 );
				continue;
			}

			$table = $seed;
			$pool  = array_values( array_diff( $pool, $table ) );

			// --- Step 3: greedy growth --------------------------------------
			while ( count( $table ) < $capacity && ! empty( $pool ) ) {
				$best      = null;
				$best_gain = null;

				foreach ( $pool as $cand ) {
					$sum   = 0;
					$count = 0;
					$ok    = true;

					foreach ( $table as $member ) {
						$key = self::pair_key( $cand, $member );
						if ( ! isset( $pairs[ $key ] ) ) {
							$ok = false; // Hard blocklist — never relaxed.
							break;
						}
						$sum += $pairs[ $key ];
						$count++;
					}

					if ( ! $ok || 0 === $count ) {
						continue;
					}

					$avg = $sum / $count;

					// Soft gender-balance term: reward the candidate that moves
					// the table closer to a 50/50 split. Fully configurable and
					// switchable from the admin panel; softened in relaxed mode.
					$avg += self::gender_balance_gain( $table, $cand, $profiles, $capacity, $relaxed );

					if ( null === $best_gain || $avg > $best_gain ) {
						$best_gain = $avg;
						$best      = $cand;
					}
				}

				if ( null === $best ) {
					break;
				}

				$table[] = $best;
				$pool    = array_values( array_diff( $pool, array( $best ) ) );
			}

			// --- Step 4: local search improvement ---------------------------
			// $pool is passed by reference so swapped-out guests go back into
			// the pool instead of silently disappearing.
			$table = self::local_search( $table, $pool, $pairs, $profiles, $capacity, $relaxed );
			$pool  = array_values( array_diff( $pool, $table ) );

			$tables[] = array(
				'members' => array_values( $table ),
				'score'   => self::table_score( $table, $pairs ),
			);

			// Keep going: leftovers deserve a table too (step 5).
			if ( count( $pool ) === 0 ) {
				break;
			}
		}

		return $tables;
	}

	/**
	 * Try to improve a seated table by swapping its weakest member with the
	 * best leftover candidate. Stops as soon as no swap improves the average.
	 *
	 * @param array $table    Seated user ids.
	 * @param array $pool     Remaining candidates (by reference).
	 * @param array $pairs    Pre-computed pair scores.
	 * @param array $profiles Profiles.
	 * @param int   $capacity Capacity.
	 * @param bool  $relaxed  Relaxed mode.
	 * @return array Possibly improved table.
	 */
	private static function local_search( $table, &$pool, $pairs, $profiles, $capacity, $relaxed ) {
		if ( count( $table ) < 3 || empty( $pool ) ) {
			return $table;
		}

		$improved = true;
		$rounds   = 0;

		while ( $improved && $rounds < 10 ) {
			$improved = false;
			$rounds++;

			$current = self::table_score( $table, $pairs ) + self::table_gender_score( $table, $profiles, $capacity, $relaxed );

			foreach ( $table as $ti => $member ) {
				foreach ( $pool as $pi => $cand ) {
					$candidate_table       = $table;
					$candidate_table[ $ti ] = $cand;

					if ( ! self::table_allowed( $candidate_table, $pairs ) ) {
						continue;
					}

					$score = self::table_score( $candidate_table, $pairs ) + self::table_gender_score( $candidate_table, $profiles, $capacity, $relaxed );

					if ( $score > $current + 0.01 ) {
						$table            = $candidate_table;
						$pool[ $pi ]      = $member;
						$current          = $score;
						$improved         = true;
						break 2;
					}
				}
			}
		}

		return $table;
	}

	/**
	 * Are all pairs of a table allowed (no hard blocklist violation)?
	 *
	 * @param array $table Members.
	 * @param array $pairs Pair scores.
	 * @return bool
	 */
	private static function table_allowed( $table, $pairs ) {
		$vals = array_values( $table );
		for ( $i = 0; $i < count( $vals ); $i++ ) {
			for ( $j = $i + 1; $j < count( $vals ); $j++ ) {
				if ( ! isset( $pairs[ self::pair_key( $vals[ $i ], $vals[ $j ] ) ] ) ) {
					return false;
				}
			}
		}
		return true;
	}

	/**
	 * Average pairwise harmony of a table.
	 *
	 * @param array $table Members.
	 * @param array $pairs Pair scores.
	 * @return float
	 */
	private static function table_score( $table, $pairs ) {
		$vals  = array_values( $table );
		$sum   = 0;
		$count = 0;

		for ( $i = 0; $i < count( $vals ); $i++ ) {
			for ( $j = $i + 1; $j < count( $vals ); $j++ ) {
				$key = self::pair_key( $vals[ $i ], $vals[ $j ] );
				if ( isset( $pairs[ $key ] ) ) {
					$sum += $pairs[ $key ];
					$count++;
				}
			}
		}

		return $count > 0 ? $sum / $count : 0.0;
	}

	/**
	 * Pairwise compatibility, base 100 (section 7 formula).
	 *
	 * @param array $a       Profile A.
	 * @param array $b       Profile B.
	 * @param bool  $relaxed Relaxed mode (soften secondary penalties).
	 * @return float|null Null when the pair is hard-blocked.
	 */
	public static function compat_score( $a, $b, $relaxed = false ) {
		// HARD CONSTRAINT: a blocklist entry is never ignored, not even in the
		// relaxed low-registration mode.
		if ( havato_is_blocked( $a['user_id'], $b['user_id'] ) ) {
			return null;
		}

		$s        = Havato_Settings::all();
		$score    = 100.0;
		$softness = $relaxed ? 0.5 : 1.0; // Relaxed mode halves secondary bonuses/penalties.

		// --- Age gap ------------------------------------------------------
		$age_a = (int) $a['age'];
		$age_b = (int) $b['age'];
		if ( $age_a > 0 && $age_b > 0 ) {
			$gap = abs( $age_a - $age_b );
			if ( $gap > (int) $s['w_age_threshold'] ) {
				$extra = $gap - (int) $s['w_age_threshold'];
				// In relaxed mode the age penalty is waived entirely (spec).
				if ( ! $relaxed ) {
					$score -= $extra * (float) $s['w_age_penalty'];
				}
			}
		}

		// --- Introvert x extrovert / two ambiverts -------------------------
		$ea = (int) $a['personality_extroversion'];
		$eb = (int) $b['personality_extroversion'];

		$a_intro = $ea <= 4;
		$b_intro = $eb <= 4;
		$a_extro = $ea >= 7;
		$b_extro = $eb >= 7;
		$a_ambi  = ( $ea >= 5 && $ea <= 6 );
		$b_ambi  = ( $eb >= 5 && $eb <= 6 );

		if ( ( $a_intro && $b_extro ) || ( $a_extro && $b_intro ) ) {
			$score += (float) $s['w_intro_extro'] * $softness;
		} elseif ( $a_ambi && $b_ambi ) {
			$score += (float) $s['w_ambivert'] * $softness;
		}

		// --- Speaker x listener --------------------------------------------
		$ta = (int) $a['personality_talkative'];
		$tb = (int) $b['personality_talkative'];

		$a_speaker  = $ta >= 7;
		$b_speaker  = $tb >= 7;
		$a_listener = $ta <= 4;
		$b_listener = $tb <= 4;

		if ( ( $a_speaker && $b_listener ) || ( $b_speaker && $a_listener ) ) {
			$score += (float) $s['w_speaker_listener'] * $softness;
		} elseif ( $a_speaker && $b_speaker ) {
			$score += (float) $s['w_two_talkers'] * $softness;
		} elseif ( $a_listener && $b_listener ) {
			$score += (float) $s['w_two_quiet'] * $softness;
		}

		// --- Shared interests ----------------------------------------------
		$ia     = array_map( 'strval', havato_json( $a['personality_interests'] ) );
		$ib     = array_map( 'strval', havato_json( $b['personality_interests'] ) );
		$shared = array_intersect( $ia, $ib );
		$score += count( $shared ) * (float) $s['w_shared_interest'] * $softness;

		// --- Conversation vibe ----------------------------------------------
		$va = isset( $a['personality_vibe'] ) ? $a['personality_vibe'] : 'fun';
		$vb = isset( $b['personality_vibe'] ) ? $b['personality_vibe'] : 'fun';
		if ( $va && $vb ) {
			if ( $va === $vb ) {
				$score += (float) $s['w_same_vibe'] * $softness;
			} else {
				$score += (float) $s['w_opposite_vibe'] * $softness;
			}
		}

		// --- Behaviour score (section 7.5) -----------------------------------
		// Users with a low rating_score are gradually pushed away from users
		// with a high rating_score: the term is the product of both normalized
		// ratings, so a 5/5 pair keeps the full bonus while a 5/1 pair loses it.
		$ra = isset( $a['rating_score'] ) ? (float) $a['rating_score'] : 5.0;
		$rb = isset( $b['rating_score'] ) ? (float) $b['rating_score'] : 5.0;
		$na = max( 0.0, min( 1.0, $ra / 5.0 ) );
		$nb = max( 0.0, min( 1.0, $rb / 5.0 ) );
		$score += ( ( $na * $nb ) - 0.5 ) * 2 * (float) $s['w_rating'] * $softness;

		// No-show penalty: repeated absentees lose priority in future matching.
		$no_show = ( (int) ( isset( $a['no_show_count'] ) ? $a['no_show_count'] : 0 ) + (int) ( isset( $b['no_show_count'] ) ? $b['no_show_count'] : 0 ) );
		$score  -= min( 15, $no_show * 2 ) * $softness;

		return $score;
	}

	/**
	 * Soft gender-balance gain of adding one candidate to a table.
	 *
	 * @param array $table    Current members.
	 * @param int   $cand     Candidate user id.
	 * @param array $profiles Profiles.
	 * @param int   $capacity Capacity.
	 * @param bool  $relaxed  Relaxed mode.
	 * @return float
	 */
	private static function gender_balance_gain( $table, $cand, $profiles, $capacity, $relaxed ) {
		if ( ! (int) Havato_Settings::get( 'gender_balance_on', 1 ) ) {
			return 0.0;
		}

		$before = self::table_gender_score( $table, $profiles, $capacity, $relaxed );
		$after  = self::table_gender_score( array_merge( $table, array( $cand ) ), $profiles, $capacity, $relaxed );

		return $after - $before;
	}

	/**
	 * Gender-balance score of a table: 0 when perfectly balanced, negative when
	 * skewed. Weight is configurable (w_gender_balance) and halved in relaxed
	 * mode so a table is still produced when only one gender registered.
	 *
	 * @param array $table    Members.
	 * @param array $profiles Profiles.
	 * @param int   $capacity Capacity.
	 * @param bool  $relaxed  Relaxed mode.
	 * @return float
	 */
	private static function table_gender_score( $table, $profiles, $capacity, $relaxed ) {
		if ( ! (int) Havato_Settings::get( 'gender_balance_on', 1 ) ) {
			return 0.0;
		}

		$weight = (float) Havato_Settings::get( 'w_gender_balance', 20 );
		if ( $relaxed ) {
			$weight *= 0.4;
		}

		$male   = 0;
		$female = 0;
		$total  = 0;

		foreach ( $table as $uid ) {
			$g = isset( $profiles[ $uid ]['gender'] ) ? $profiles[ $uid ]['gender'] : '';
			if ( 'male' === $g ) {
				$male++;
				$total++;
			} elseif ( 'female' === $g ) {
				$female++;
				$total++;
			}
		}

		if ( $total < 2 ) {
			return 0.0;
		}

		// Skew: 0 = perfect 50/50, 1 = single gender table.
		$skew = abs( $male - $female ) / $total;

		return -$skew * $weight;
	}

	/**
	 * Load profiles keyed by user id, creating defaults where missing.
	 *
	 * @param array $user_ids User ids.
	 * @return array
	 */
	private static function load_profiles( $user_ids ) {
		$out = array();
		foreach ( $user_ids as $uid ) {
			$profile              = havato_get_profile( $uid );
			$profile['user_id']   = (int) $uid;
			$out[ (int) $uid ]    = $profile;
		}
		return $out;
	}

	/**
	 * Deterministic key for a user pair.
	 *
	 * @param int $a First.
	 * @param int $b Second.
	 * @return string
	 */
	private static function pair_key( $a, $b ) {
		$a = (int) $a;
		$b = (int) $b;
		return $a < $b ? $a . ':' . $b : $b . ':' . $a;
	}

	/**
	 * Drop the welcome system message into a fresh group chat.
	 *
	 * @param string $group_id Group id.
	 * @param array  $event    Event row.
	 */
	private static function system_message( $group_id, $event ) {
		global $wpdb;
		$chats = Havato_DB::table( 'chats' );
		$venue = self::venue_name( $event['venue_id'] );

		$text = sprintf(
			'میز شما چیده شد! %s — %s ساعت %s | Your table is ready at %s.',
			$venue['fa'],
			Havato_Jalali::format( $event['event_date'], 'fa' ),
			Havato_Jalali::fa_digits( substr( $event['event_time'], 0, 5 ) ),
			$venue['en']
		);

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->insert(
			$chats,
			array(
				'group_id'     => $group_id,
				'sender_id'    => 0,
				'sender_name'  => 'Havato',
				'message_text' => $text,
				'message_time' => havato_now(),
				'is_system'    => 1,
			),
			array( '%s', '%d', '%s', '%s', '%s', '%d' )
		);
	}

	/**
	 * Venue names in both languages.
	 *
	 * @param string $venue_id Venue id.
	 * @return array{fa:string,en:string}
	 */
	private static function venue_name( $venue_id ) {
		global $wpdb;
		$venues = Havato_DB::table( 'venues' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$row = $wpdb->get_row( $wpdb->prepare( "SELECT name FROM $venues WHERE id=%s", $venue_id ), ARRAY_A );
		if ( ! $row ) {
			return array( 'fa' => 'کافه', 'en' => 'Café' );
		}
		// One canonical café name, used in both languages.
		return array(
			'fa' => $row['name'],
			'en' => $row['name'],
		);
	}

	/**
	 * Update the venue KPI counters after a successful match.
	 *
	 * @param string $venue_id Venue id.
	 * @param int    $guests   Guests routed.
	 */
	private static function bump_venue_stats( $venue_id, $guests ) {
		global $wpdb;
		$venues = Havato_DB::table( 'venues' );

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$wpdb->query( $wpdb->prepare( "UPDATE $venues SET guests_routed = guests_routed + %d WHERE id=%s", (int) $guests, $venue_id ) );

		// Utilization = rolling ratio of routed guests vs. offered seats.
		$events = Havato_DB::table( 'events' );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$seats = (int) $wpdb->get_var( $wpdb->prepare( "SELECT SUM(max_capacity) FROM $events WHERE venue_id=%s", $venue_id ) );
		// phpcs:ignore WordPress.DB.DirectDatabaseQuery, WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$routed = (int) $wpdb->get_var( $wpdb->prepare( "SELECT guests_routed FROM $venues WHERE id=%s", $venue_id ) );

		$util = $seats > 0 ? min( 100, (int) round( ( $routed / $seats ) * 100 ) ) : 0;

		// phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->update( $venues, array( 'utilization' => $util ), array( 'id' => $venue_id ), array( '%d' ), array( '%s' ) );
	}
}
