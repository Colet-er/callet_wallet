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

function parseCbcCardAlert(message: string) {
  const card = message.match(
    /Thank you for using\s+CBC\s+Card\s+ending in\s+(\d{4})\s*:/i,
  );
  const amount = message.match(/\bPHP\s*([\d,]+(?:\.\d{1,2})?)\b/i);
  const date = message.match(/\b(\d{1,2})\/(\d{1,2})\/(\d{2}|\d{4})\b/);

  if (!card || !amount || !date) return null;

  const majorAmount = Number(amount[1].replaceAll(',', ''));
  const amountCents = Math.round(majorAmount * 100);
  if (!Number.isSafeInteger(amountCents) || amountCents <= 0) return null;

  const year = Number(date[3].length === 2 ? `20${date[3]}` : date[3]);
  const month = Number(date[1]);
  const day = Number(date[2]);
  const occurred = new Date(Date.UTC(year, month - 1, day));
  if (
    occurred.getUTCFullYear() !== year ||
    occurred.getUTCMonth() !== month - 1 ||
    occurred.getUTCDate() !== day
  ) return null;

  return {
    last4: card[1],
    amountCents,
    occurredOn: `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`,
    description: `CBC card ••••${card[1]}`,
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

  const parsed = parseCbcCardAlert(body.message);
  if (!parsed) {
    return json(422, {
      error: 'This SMS does not match the supported CBC card purchase format.',
    });
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

  const cbcWallets = (walletRows ?? []).filter((wallet) => {
    const name = String(wallet.name).toLowerCase();
    return name.includes('cbc') || name.includes('china bank');
  });
  if (cbcWallets.length === 0) {
    return json(409, { error: 'Add a wallet named CBC or China Bank before importing this alert.' });
  }
  if (cbcWallets.length > 1) {
    return json(409, { error: 'More than one CBC/China Bank wallet matches. Rename the intended wallet so only one matches.' });
  }

  const smsFingerprint = await sha256(body.message.trim());
  const { error: insertError } = await admin.from('transactions').insert({
    user_id: tokenRow.user_id,
    wallet_id: cbcWallets[0].id,
    type: 'expense',
    description: parsed.description,
    category: 'Card purchase',
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
    type: 'expense',
    amount: parsed.amountCents / 100,
    currency: 'PHP',
    occurred_on: parsed.occurredOn,
    wallet: cbcWallets[0].name,
    message: 'CBC card expense imported.',
  });
});
