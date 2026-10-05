/**
 * GET /api/contacts/export - download the contact list as a CSV file.
 * Same auth + ownership scoping as /api/contacts. UTF-8 with BOM so Persian
 * text opens correctly in Excel; dates are Jalali for readability.
 */

import { getAuthenticatedUser, unauthorized } from '@/lib/auth';
import { createServiceClient } from '@/lib/supabase/service';
import { createLogger } from '@/lib/logger';
import { faDate } from '@/lib/utils';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const logger = createLogger('api:contacts-export');

const EXPORT_LIMIT = 5000;

const TRIGGER_LABELS: Record<string, string> = {
  comment: 'کامنت',
  dm: 'کلیدواژه دایرکت',
  story_reply: 'پاسخ استوری',
  button: 'لمس دکمه',
};

function csvCell(value: string): string {
  return `"${value.replace(/"/g, '""')}"`;
}

export async function GET(request: Request): Promise<Response> {
  const user = await getAuthenticatedUser(request);
  if (!user) return unauthorized();

  const db = createServiceClient();

  const { data: accounts, error: accountsError } = await db
    .from('instagram_accounts')
    .select('id')
    .eq('user_id', user.id);

  if (accountsError) {
    logger.error({ err: accountsError, userId: user.id }, 'Failed to fetch accounts for export');
    return Response.json({ error: 'Failed to export contacts' }, { status: 500 });
  }

  const accountIds = (accounts ?? []).map((a) => a.id as string);
  if (accountIds.length === 0) {
    return Response.json({ error: 'No connected accounts' }, { status: 404 });
  }

  const requestedAccountId = new URL(request.url).searchParams.get('accountId');
  let scopedIds = accountIds;
  if (requestedAccountId) {
    if (!accountIds.includes(requestedAccountId)) {
      return Response.json({ error: 'Instagram account not found' }, { status: 404 });
    }
    scopedIds = [requestedAccountId];
  }

  const { data, error } = await db
    .from('contacts')
    .select(
      `
      username, audience_ig_user_id, follows_business,
      first_interaction_at, last_interaction_at, last_trigger_type, total_triggers,
      automations ( id, name )
    `
    )
    .in('instagram_account_id', scopedIds)
    .order('last_interaction_at', { ascending: false })
    .limit(EXPORT_LIMIT);

  if (error) {
    logger.error({ err: error, userId: user.id }, 'Failed to fetch contacts for export');
    return Response.json({ error: 'Failed to export contacts' }, { status: 500 });
  }

  const header = [
    'نام کاربری',
    'شناسه اینستاگرام',
    'وضعیت فالو',
    'نوع آخرین تعامل',
    'خودکارساز',
    'تعداد تعاملات',
    'اولین تعامل',
    'آخرین تعامل',
  ];

  const rows = (data ?? []).map((c) => {
    const contact = c as unknown as {
      username: string | null;
      audience_ig_user_id: string;
      follows_business: boolean | null;
      first_interaction_at: string;
      last_interaction_at: string;
      last_trigger_type: string | null;
      total_triggers: number;
      automations: { name: string }[] | null;
    };
    return [
      contact.username ? `@${contact.username}` : '',
      contact.audience_ig_user_id,
      contact.follows_business === true ? 'فالو کرده' : contact.follows_business === false ? 'فالو نکرده' : 'نامشخص',
      contact.last_trigger_type ? (TRIGGER_LABELS[contact.last_trigger_type] ?? contact.last_trigger_type) : '',
      contact.automations?.[0]?.name ?? '',
      String(contact.total_triggers),
      faDate(contact.first_interaction_at, { month: 'long', day: 'numeric', year: 'numeric' }),
      faDate(contact.last_interaction_at, { month: 'long', day: 'numeric', year: 'numeric' }),
    ];
  });

  // BOM (uFEFF) so Excel detects UTF-8; CRLF row endings for maximum compat.
  const csv = '\uFEFF' + [header, ...rows].map((r) => r.map(csvCell).join(',')).join('\r\n');
  const filename = `contacts-${new Date().toISOString().slice(0, 10)}.csv`;

  return new Response(csv, {
    headers: {
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': `attachment; filename="${filename}"`,
    },
  });
}
