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

function parseSmsMessage(message: string) {
  const card = message.match(
    /Thank you for using\s+CBC\s+Card\s+ending in\s+(\d{4})\s*:/i,
  );
  const amount = message.match(/(?:\bPHP\s*|₱\s*)([\d,]+(?:\.\d{1,2})?)\b/i);
  const date = message.match(
    /\b(\d{4})-(\d{1,2})-(\d{1,2})\b|\b(\d{1,2})\/(\d{1,2})\/(\d{2}|\d{4})\b/,
  );
  const namedDate = message.match(
    /\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+(\d{4})\b/i,
  );
  const saysIncome = /\b(credited|credit(?:ed)? to|received|deposit(?:ed)?|cash[ -]?in|refund(?:ed)?)\b/i.test(message);
  const saysExpense =
    /\b(debited|deducted|withdraw(?:n|al)?|purchase|paid|payment|sent|cash[ -]?out)\b/i.test(message) ||
    (/\btransfer(?:red)?\b/i.test(message) && /\bfrom\b/i.test(message) && !saysIncome);

  if (!amount) return { error: 'Could not find a PHP amount in this SMS.' };
  if (saysIncome === saysExpense && !card) {
    return { error: 'Could not tell whether this SMS is income or an expense.' };
  }

  const type = card || saysExpense ? 'expense' : 'income';
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

  const isCbc = /\b(?:CBC|China Bank|China Banking Corporation)\b/i.test(message);
  const isGcash = /\bGCash\b/i.test(message);
  if (Number(isCbc) + Number(isGcash) !== 1) {
    return { error: 'Could not identify a single CBC or GCash wallet from this SMS.' };
  }

  const brand = isCbc ? 'CBC' : 'GCash';
  const cardDescription = card ? `CBC card ••••${card[1]}` : `${brand} SMS ${type}`;
  return {
    type,
    amountCents,
    occurredOn,
    description: cardDescription,
    category: card ? 'Card purchase' : type === 'income' ? 'Income' : 'Expense',
    walletMatch: isCbc ? ['cbc', 'china bank'] : ['gcash'],
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

  const parsed = parseSmsMessage(body.message);
  if ('error' in parsed) {
    return json(422, { error: parsed.error });
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
    .select('id, name')
    .eq('user_id', tokenRow.user_id);
  if (walletError) return json(500, { error: 'Could not find your wallets.' });

  const matchingWallets = (walletRows ?? []).filter((wallet) => {
    const name = String(wallet.name).toLowerCase();
    return parsed.walletMatch.some((match) => name.includes(match));
  });
  if (matchingWallets.length === 0) {
    return json(409, { error: `Add a wallet named ${parsed.walletMatch.join(' or ')} before importing this alert.` });
  }
  if (matchingWallets.length > 1) {
    return json(409, { error: 'More than one matching wallet was found. Rename the intended wallet so only one matches.' });
  }

  const smsFingerprint = await sha256(body.message.trim());
  const { error: insertError } = await admin.from('transactions').insert({
    user_id: tokenRow.user_id,
    wallet_id: matchingWallets[0].id,
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
    wallet: matchingWallets[0].name,
    message: `SMS ${parsed.type} imported.`,
  });
});
