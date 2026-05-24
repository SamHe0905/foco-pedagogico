import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

// ── Tipos ─────────────────────────────────────────────────────────────────────

interface ServiceAccount {
  project_id: string
  client_email: string
  private_key: string
}

// ── Helpers JWT / OAuth2 ──────────────────────────────────────────────────────

function base64url(data: ArrayBuffer | string): string {
  let str: string
  if (typeof data === 'string') {
    str = btoa(unescape(encodeURIComponent(data)))
  } else {
    const bytes = new Uint8Array(data)
    str = btoa(String.fromCharCode(...bytes))
  }
  return str.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function pemToDer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes.buffer
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const claim = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }

  const header  = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = base64url(JSON.stringify(claim))
  const input   = `${header}.${payload}`

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(input))
  const jwt = `${input}.${base64url(sig)}`

  const res  = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })

  if (!res.ok) throw new Error(`OAuth2 error: ${await res.text()}`)
  return (await res.json()).access_token as string
}

// ── Envio FCM HTTP v1 ─────────────────────────────────────────────────────────

async function sendFcm(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: {
            priority: 'high',
            notification: { channel_id: 'demandas' },
          },
        },
      }),
    },
  )

  const resBody = await res.json()
  if (!res.ok) {
    console.error(`FCM error [${token.slice(0, 16)}...]:`, JSON.stringify(resBody))
  } else {
    console.log(`FCM ok [${token.slice(0, 16)}...]:`, JSON.stringify(resBody))
  }
}

// ── Handler principal ─────────────────────────────────────────────────────────

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    // Valida auth
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Não autorizado.' }, 401)

    const { demanda_id, tipo } = await req.json()
    if (!demanda_id) return json({ error: 'demanda_id obrigatório.' }, 400)
    const lembrete = tipo === 'lembrete'

    // Carrega service account do Firebase
    const saJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!saJson) return json({ error: 'FIREBASE_SERVICE_ACCOUNT não configurado.' }, 500)
    const sa: ServiceAccount = JSON.parse(saJson)

    // Obtém token OAuth2 para FCM
    const accessToken = await getAccessToken(sa)

    // Busca título da demanda
    const { data: demanda } = await supabaseAdmin
      .from('demandas')
      .select('titulo')
      .eq('id', demanda_id)
      .single()

    if (!demanda) return json({ error: 'Demanda não encontrada.' }, 404)

    // Busca IDs dos professores atribuídos
    const { data: assignments } = await supabaseAdmin
      .from('demanda_professor')
      .select('professor_id')
      .eq('demanda_id', demanda_id)

    if (!assignments || assignments.length === 0) return json({ ok: true, sent: 0 })

    const professorIds = assignments.map((a: { professor_id: string }) => a.professor_id)

    // Busca tokens FCM dos professores
    const { data: profiles } = await supabaseAdmin
      .from('profiles')
      .select('fcm_token')
      .in('id', professorIds)
      .not('fcm_token', 'is', null)

    console.log(`[notify] professor_ids: ${JSON.stringify(professorIds)}`)
    console.log(`[notify] profiles com token: ${profiles?.length ?? 0}`)

    if (!profiles || profiles.length === 0) return json({ ok: true, sent: 0 })

    // Envia notificações em paralelo
    const titulo = lembrete ? '⚠️ Demanda atrasada' : 'Nova demanda'
    await Promise.all(
      profiles
        .filter((p: { fcm_token: string | null }) => p.fcm_token)
        .map((p: { fcm_token: string }) =>
          sendFcm(
            accessToken,
            sa.project_id,
            p.fcm_token,
            titulo,
            demanda.titulo,
            { demanda_id },
          )
        ),
    )

    return json({ ok: true, sent: profiles.length })
  } catch (e) {
    console.error(e)
    return json({ error: 'Erro interno.' }, 500)
  }
})
