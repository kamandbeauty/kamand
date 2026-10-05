/**
 * GET /api/contacts - the automation-captured audience list.
 * Contacts are scoped to the authenticated user's connected accounts.
 * Paginated (?page=&pageSize=) with an exact total for the UI pager.
 */

import { getAuthenticatedUser, unauthorized } from '@/lib/auth';
import { createServiceClient } from '@/lib/supabase/service';
import { createLogger } from '@/lib/logger';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const logger = createLogger('api:contacts');

export async function GET(request: Request): Promise<Response> {
  const user = await getAuthenticatedUser(request);
  if (!user) return unauthorized();

  const url = new URL(request.url);
  const page = Math.max(1, parseInt(url.searchParams.get('page') ?? '1', 10) || 1);
  const pageSize = Math.min(200, Math.max(1, parseInt(url.searchParams.get('pageSize') ?? '100', 10) || 100));

  const db = createServiceClient();

  // Resolve the user's accounts first, then fetch their contacts.
  const { data: accounts, error: accountsError } = await db
    .from('instagram_accounts')
    .select('id, username')
    .eq('user_id', user.id);

  if (accountsError) {
    logger.error({ err: accountsError, userId: user.id }, 'Failed to fetch accounts for contacts');
    return Response.json({ error: 'Failed to fetch contacts' }, { status: 500 });
  }

  const accountIds = (accounts ?? []).map((a) => a.id as string);
  if (accountIds.length === 0) {
    return Response.json({ contacts: [], total: 0, page, pageSize, hasMore: false });
  }

  // Optional per-account scoping. SECURITY: the requested id must be one of
  // the authenticated user's own accounts - anything else is a 404.
  const requestedAccountId = url.searchParams.get('accountId');
  let scopedIds = accountIds;
  if (requestedAccountId) {
    if (!accountIds.includes(requestedAccountId)) {
      return Response.json({ error: 'Instagram account not found' }, { status: 404 });
    }
    scopedIds = [requestedAccountId];
  }

  const { data, error, count } = await db
    .from('contacts')
    .select(
      `
      id, instagram_account_id, audience_ig_user_id, username, follows_business,
      first_interaction_at, last_interaction_at, last_trigger_type, total_triggers,
      automations ( id, name )
    `,
      { count: 'exact' }
    )
    .in('instagram_account_id', scopedIds)
    .order('last_interaction_at', { ascending: false })
    .range((page - 1) * pageSize, page * pageSize - 1);

  if (error) {
    logger.error({ err: error, userId: user.id }, 'Failed to fetch contacts');
    return Response.json({ error: 'Failed to fetch contacts' }, { status: 500 });
  }

  const total = count ?? 0;
  return Response.json({
    contacts: data ?? [],
    total,
    page,
    pageSize,
    hasMore: page * pageSize < total,
  });
}
