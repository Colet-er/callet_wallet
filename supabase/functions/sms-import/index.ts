import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type, x-callet-token',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

type WalletRow = {
  id: string;
  name: string;
  type: string;
  account_last4: string | null;
};

function uniqueWallet(matches: WalletRow[]): WalletRow | null {
  const unique = [...new Map(matches.map((wallet) => [wallet.id, wallet])).values()];
  return unique.length === 1 ? unique[0] : null;
}

function walletsForLast4(wallets: WalletRow[], last4: string | undefined): WalletRow[] {
  if (!last4) return [];
  return wallets.filter((wallet) => wallet.type !== 'cash' && wallet.account_last4 === last4);
}

function parseSmsMessage(message: string, wallets: WalletRow[]) {
  const card = message.match(/\bcard ending in\s+(\d{4})\b/i);
  const amount = message.match(/(?:\bPHP\s*|\bP\s*|₱\s*)([\d,]+(?:\.\d{1,2})?)\b/i);
  const date = message.match(
    /\b(\d{4})-(\d{1,2})-(\d{1,2})\b|\b(\d{1,2})\/(\d{1,2})\/(\d{2}|\d{4})\b/,
  );
  const namedDate = message.match(
    /\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+(\d{4})\b/i,
  );
  const saysIncome = /\b(credited|credit(?:ed)? to|received|deposit(?:ed)?|cash[ -]?in|refund(?:ed)?|top[ -]?up)\b/i.test(message);
  const transfer = /\btransfer(?:red|s)?\b/i.test(message);
  const saysExpense =
    /\b(debited|deducted|withdraw(?:n|al)?|purchase|paid|payment|sent|cash[ -]?out|spent|charged)\b/i.test(message) ||
    (transfer && !saysIncome);

  if (!amount) return { error: 'Could not find a PHP amount in this SMS.' };
  if (saysIncome === saysExpense && !card) {
    return { error: 'Could not tell whether this SMS is income or an expense.' };
  }

  const direction = card || saysExpense ? 'expense' : 'income';
  const majorAmount = Number(amount[1].replaceAll(',', ''));
  const amountCents = Math.round(majorAmount * 100);
  if (!Number.isSafeInteger(amountCents) || amountCents <= 0) {
    return { error: 'The amount in this SMS is invalid.' };
  }

  let occurredOn: string;
  if (date || namedDate) {
    const monthNames = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
    ];
    const year = Number(namedDate
      ? namedDate[3]
      : date![1]
        ? date![1]
        : date![6].length === 2
          ? `20${date![6]}`
          : date![6]);
    const month = Number(namedDate
      ? monthNames.indexOf(namedDate[1].toLowerCase()) + 1
      : date![1]
        ? date![2]
        : date![4]);
    const day = Number(namedDate ? namedDate[2] : date![1] ? date![3] : date![5]);
    const occurred = new Date(Date.UTC(year, month - 1, day));
    if (
      occurred.getUTCFullYear() !== year ||
      occurred.getUTCMonth() !== month - 1 ||
      occurred.getUTCDate() !== day
    ) return { error: 'The date in this SMS is invalid.' };
    occurredOn = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  } else {
    occurredOn = new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString().slice(0, 10);
  }

  const fromLast4 = message.match(/\bfrom\b[\s\S]{0,50}?(?:\*{2,}|x{2,}|ending(?:\s+in)?\s*)(\d{4})\b/i)?.[1];
  const toLast4 = message.match(/\bto\b[\s\S]{0,50}?(?:\*{2,}|x{2,}|ending(?:\s+in)?\s*)(\d{4})\b/i)?.[1];
  const cardLast4 = card?.[1];
  const sourceById = uniqueWallet(walletsForLast4(wallets, fromLast4 ?? cardLast4));
  const destinationById = uniqueWallet(walletsForLast4(wallets, toLast4));
  const allLast4s = [...message.matchAll(/(?:\*{2,}|x{2,}|ending(?:\s+in)?\s*)(\d{4})\b/gi)]
    .map((match) => match[1]);
  const matchedWallets = uniqueWallet(allLast4s.flatMap((last4) =>
    walletsForLast4(wallets, last4)));
  const source = sourceById ?? (direction === 'expense' ? matchedWallets : null);
  const destination = destinationById ?? (direction === 'income' ? matchedWallets : null);

  if (fromLast4 && walletsForLast4(wallets, fromLast4).length > 1) {
    return { error: `More than one wallet uses account ending ${fromLast4}. Give each wallet a unique last four digits.` };
  }
  if (toLast4 && walletsForLast4(wallets, toLast4).length > 1) {
    return { error: `More than one wallet uses account ending ${toLast4}. Give each wallet a unique last four digits.` };
  }

  for (const last4 of allLast4s) {
    if (walletsForLast4(wallets, last4).length > 1) {
      return { error: `More than one wallet uses account ending ${last4}. Give each wallet a unique last four digits.` };
    }
  }

  let wallet: WalletRow | null = null;
  let transferTo: WalletRow | null = null;
  let type: 'income' | 'expense' | 'transfer' = direction;
  if (transfer && source && destination && source.id !== destination.id) {
    type = 'transfer';
    wallet = source;
    transferTo = destination;
  } else if (transfer && direction === 'expense') {
    return { error: 'This transfer SMS must include the receiving wallet account ending in its last four digits. If it does not, record the transfer manually in Activity.' };
  } else if (direction === 'expense') {
    wallet = source;
  } else {
    wallet = destination;
  }
  if (!wallet) {
    return { error: 'Could not match this SMS to a wallet. Add the matching account last four digits in the wallet settings and make sure the SMS includes them.' };
  }

  const description = type === 'transfer'
    ? `Transfer to ${transferTo!.name}`
    : card
      ? `${wallet.name} card ••••${card[1]}`
      : `${wallet.name} SMS ${type}`;
  return {
    type,
    amountCents,
    occurredOn,
    description,
    category: type === 'transfer' ? 'Transfer' : card ? 'Card purchase' : type === 'income' ? 'Income' : 'Expense',
    walletId: wallet.id,
    transferToWalletId: transferTo?.id ?? null,
    walletName: wallet.name,
  };
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') return json(405, { error: 'Use POST.' });

  const token = request.headers.get('x-callet-token')?.trim();
  if (!token || token.length < 32) return json(401, { error: 'Missing or invalid Callet token.' });

  let body: { message?: unknown };
  try {
    body = await request.json();
  } catch {
    return json(400, { error: 'Request body must be JSON.' });
  }
  if (typeof body.message !== 'string' || body.message.length > 1500) {
    return json(400, { error: 'Include the SMS text in a message field (maximum 1500 characters).' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceKey) return json(500, { error: 'SMS import is not configured.' });

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const tokenHash = await sha256(token);
  const { data: tokenRow, error: tokenError } = await admin
    .from('sms_import_tokens')
    .select('user_id')
    .eq('token_hash', tokenHash)
    .maybeSingle();
  if (tokenError) return json(500, { error: 'Could not validate the Callet token.' });
  if (!tokenRow) return json(401, { error: 'Callet token is invalid or has been revoked.' });

  const { data: walletRows, error: walletError } = await admin
    .from('wallets')
    .select('id, name, type, account_last4')
    .eq('user_id', tokenRow.user_id);
  if (walletError) return json(500, { error: 'Could not find your wallets.' });

  const parsed = parseSmsMessage(
    body.message,
    ((walletRows ?? []) as WalletRow[]).filter((wallet) => wallet.type !== 'cash'),
  );
  if ('error' in parsed) {
    return json(422, { error: parsed.error });
  }

  const smsFingerprint = await sha256(body.message.trim());
  const { error: insertError } = await admin.from('transactions').insert({
    user_id: tokenRow.user_id,
    wallet_id: parsed.walletId,
    transfer_to_wallet_id: parsed.transferToWalletId,
    type: parsed.type,
    description: parsed.description,
    category: parsed.category,
    amount_cents: parsed.amountCents,
    occurred_on: parsed.occurredOn,
    sms_fingerprint: smsFingerprint,
  });

  if (insertError?.code === '23505') {
    return json(200, { imported: false, duplicate: true, message: 'This SMS was already imported.' });
  }
  if (insertError) return json(500, { error: 'Could not save this transaction.' });

  return json(201, {
    imported: true,
    type: parsed.type,
    amount: parsed.amountCents / 100,
    currency: 'PHP',
    occurred_on: parsed.occurredOn,
    wallet: parsed.walletName,
    destination_wallet: parsed.transferToWalletId ? parsed.description.replace(/^Transfer to /, '') : null,
    message: `SMS ${parsed.type} imported.`,
  });
});
