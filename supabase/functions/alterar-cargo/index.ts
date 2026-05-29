import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

// Roles que cada nível pode atribuir
const ROLES_COORDENADOR = new Set(['professor', 'professor_aee', 'supervisor', 'coordenacao', 'pcsa'])
const ROLES_DIRETOR     = new Set(['professor', 'professor_aee', 'supervisor', 'coordenacao', 'pcsa', 'diretor', 'diretor-adjunto', 'secretaria'])

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

    // ── Autentica o chamador ─────────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization') ?? ''
    const token = authHeader.replace('Bearer ', '').trim()
    if (!token) return json({ error: 'Não autenticado.' }, 401)

    let callerId: string
    try {
      const payload = token.split('.')[1]
      const claims  = JSON.parse(atob(payload))
      callerId = claims.sub as string
    } catch {
      return json({ error: 'Token inválido.' }, 401)
    }

    // ── Verifica permissão do chamador ───────────────────────────────────────
    const { data: perfil } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', callerId)
      .single()

    const myRole     = perfil?.role as string | undefined
    const isDirector = myRole === 'diretor' || myRole === 'diretor-adjunto' || myRole === 'secretaria'
    const isCoordenador = myRole === 'coordenacao' || myRole === 'supervisor' || myRole === 'pcsa'

    if (!isDirector && !isCoordenador) {
      return json({ error: 'Sem permissão.' }, 403)
    }

    // ── Lê body ──────────────────────────────────────────────────────────────
    const body = await req.json()
    const { userId, novoRole } = body

    if (!userId || !novoRole) {
      return json({ error: 'userId e novoRole são obrigatórios.' }, 400)
    }

    if (userId === callerId) {
      return json({ error: 'Você não pode alterar seu próprio cargo.' }, 400)
    }

    const roleNorm = (novoRole as string).trim().toLowerCase()

    // Verifica se o role solicitado é permitido para este nível
    const rolesPermitidos = isDirector ? ROLES_DIRETOR : ROLES_COORDENADOR
    if (!rolesPermitidos.has(roleNorm)) {
      return json({ error: 'Sem permissão para atribuir este cargo.' }, 403)
    }

    // Coordenadores não podem alterar cargos de diretores
    if (!isDirector) {
      const { data: alvo } = await supabaseAdmin
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single()

      const roleAlvo = alvo?.role as string | undefined
      if (roleAlvo === 'diretor' || roleAlvo === 'diretor-adjunto' || roleAlvo === 'secretaria') {
        return json({ error: 'Sem permissão para alterar o cargo deste usuário.' }, 403)
      }
    }

    // ── Monta update ─────────────────────────────────────────────────────────
    const updateData: Record<string, unknown> = { role: roleNorm }

    // role_secundario é opcional. Se a chave veio no body (mesmo como null/""),
    // atualizamos: string vazia ou null = limpar; string válida = setar.
    if ('novoRoleSecundario' in body) {
      const raw = body.novoRoleSecundario
      if (raw === null || raw === '' || raw === undefined) {
        updateData.role_secundario = null
      } else {
        const secNorm = String(raw).trim().toLowerCase()
        if (!rolesPermitidos.has(secNorm)) {
          return json({ error: 'Sem permissão para atribuir este cargo secundário.' }, 403)
        }
        if (secNorm === roleNorm) {
          return json({ error: 'O cargo secundário deve ser diferente do principal.' }, 400)
        }
        updateData.role_secundario = secNorm
      }
    }

    // ── Aplica a alteração ───────────────────────────────────────────────────
    const { error: updateErr } = await supabaseAdmin
      .from('profiles')
      .update(updateData)
      .eq('id', userId)

    if (updateErr) return json({ error: updateErr.message }, 400)

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
