import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

// Roles que cada nível pode convidar
const ROLES_COORDENADOR = ['professor', 'supervisor', 'coordenacao']
const ROLES_DIRETOR     = ['professor', 'supervisor', 'coordenacao', 'diretor', 'diretor-adjunto']

const ROLES_VALIDOS = new Set(ROLES_DIRETOR)

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } },
    )

    // ── Extrai userId do JWT ─────────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization') ?? ''
    const token = authHeader.replace('Bearer ', '').trim()
    if (!token) return json({ error: 'Não autenticado.' }, 401)

    let userId: string
    try {
      const payload = token.split('.')[1]
      const claims  = JSON.parse(atob(payload))
      userId = claims.sub as string
    } catch {
      return json({ error: 'Token inválido.' }, 401)
    }

    // ── Verifica role de quem está convidando ────────────────────────────────
    const { data: perfil } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', userId)
      .single()

    const myRole     = perfil?.role as string | undefined
    const isDirector = myRole === 'diretor' || myRole === 'diretor-adjunto'
    const isCoordenador = myRole === 'coordenacao' || myRole === 'supervisor'

    if (!isDirector && !isCoordenador) {
      return json({ error: 'Sem permissão.' }, 403)
    }

    // ── Lê body ──────────────────────────────────────────────────────────────
    const { email, nome, role } = await req.json()

    if (!email || !nome || !role) {
      return json({ error: 'email, nome e role são obrigatórios.' }, 400)
    }

    const roleNorm  = (role  as string).trim().toLowerCase()
    const emailNorm = (email as string).trim().toLowerCase()
    const nomeNorm  = (nome  as string).trim()

    // ── Verifica se o role é válido e se quem convida tem permissão ──────────
    if (!ROLES_VALIDOS.has(roleNorm)) {
      return json({ error: `Cargo inválido: ${roleNorm}` }, 400)
    }

    const rolesPermitidos = isDirector ? ROLES_DIRETOR : ROLES_COORDENADOR
    if (!rolesPermitidos.includes(roleNorm)) {
      return json({ error: 'Sem permissão para convidar este cargo.' }, 403)
    }

    // ── Convida ──────────────────────────────────────────────────────────────
    const { data: invited, error: inviteErr } =
      await supabaseAdmin.auth.admin.inviteUserByEmail(emailNorm, {
        data: { nome: nomeNorm, role: roleNorm },
      })

    if (inviteErr) {
      return json({ error: inviteErr.message }, 400)
    }

    // ── Garante profile com o cargo correto ──────────────────────────────────
    if (invited.user) {
      await supabaseAdmin
        .from('profiles')
        .upsert(
          { id: invited.user.id, nome: nomeNorm, role: roleNorm },
          { onConflict: 'id' },
        )
    }

    return json({ success: true })
  } catch (err) {
    console.error(err)
    return json({ error: String(err) }, 500)
  }
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
