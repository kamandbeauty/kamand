'use client';

import { useQuery, useInfiniteQuery } from '@tanstack/react-query';
import { apiClient } from '@/lib/api/client';

export interface ContactFromDB {
  id: string;
  instagram_account_id: string;
  audience_ig_user_id: string;
  username: string | null;
  follows_business: boolean | null;
  first_interaction_at: string;
  last_interaction_at: string;
  last_trigger_type: 'comment' | 'dm' | 'story_reply' | 'button' | null;
  total_triggers: number;
  automations: { id: string; name: string } | null;
}

export interface ContactsPage {
  contacts: ContactFromDB[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

/** First page + exact total - used for dashboard counters. */
export function useContacts(accountId?: string | null) {
  return useQuery({
    queryKey: ['contacts', accountId ?? 'all', 1],
    queryFn: () =>
      apiClient<ContactsPage>(
        `/contacts?page=1${accountId ? `&accountId=${encodeURIComponent(accountId)}` : ''}`
      ),
    staleTime: 30 * 1000,
    refetchInterval: 60 * 1000, // contacts grow as automations fire - keep fresh
  });
}

/** Paginated feed for the Contacts list (Load more). */
export function useContactsInfinite(accountId?: string | null) {
  return useInfiniteQuery<ContactsPage, Error>({
    queryKey: ['contacts-infinite', accountId ?? 'all'],
    queryFn: ({ pageParam }) =>
      apiClient<ContactsPage>(
        `/contacts?page=${pageParam}${accountId ? `&accountId=${encodeURIComponent(accountId)}` : ''}`
      ),
    initialPageParam: 1,
    getNextPageParam: (lastPage) => (lastPage.hasMore ? lastPage.page + 1 : undefined),
    staleTime: 30 * 1000,
  });
}
